import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {

  final _picker = ImagePicker();
  File? _selectedImage;

  final _foodsController = TextEditingController();

  String _mealType = 'breakfast'; // breakfast | lunch | dinner | snack
  DateTime _selectedDate = DateTime.now();

  bool _saving = false;
  bool _gptLoading = false;
  Map<String, dynamic>? _gptJson; // {items:[{name, grams, kcal}], total_kcal}

  @override
  void dispose() {
    _foodsController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile =
    await _picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ===== 저장 전: 반드시 GPT 칼로리 추정 보장 =====
  Future<bool> _ensureGptKcal() async {
    final foodsText = _foodsController.text.trim();

    if (foodsText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먹은 음식을 입력해 주세요. (칼로리 추정을 위해 필요)')),
        );
      }
      return false;
    }

    if (_gptJson != null) return true; // 이미 계산됨

    setState(() => _gptLoading = true);
    try {
      final resp = await http.post(
        Uri.parse('$serverUrl/calc-calories'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'foods': foodsText,
          'mealType': _mealType,
          'locale': 'ko-KR',
          'units': 'metric',
        }),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() => _gptJson = json);
        return true;
      } else {
        debugPrint('ensure gpt error: ${resp.statusCode} ${resp.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('칼로리 추정 실패(${resp.statusCode}). 다시 시도해 주세요.')),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('ensure gpt exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('칼로리 추정 중 오류: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _gptLoading = false);
    }
  }

  // ===== 저장: (자동 GPT) + Storage 업로드 + Firestore 기록 =====
  Future<void> _saveMeal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    final uid = user.uid;

    final foodsText = _foodsController.text.trim();
    final foods = foodsText.isEmpty
        ? <String>[]
        : foodsText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음식 입력이 필요합니다. (저장 시 자동 칼로리 추정)')),
      );
      return;
    }

    // 저장 전에 GPT 추정 보장
    final ok = await _ensureGptKcal();
    if (!ok) return;

    setState(() => _saving = true);
    try {
      final dateKey = _dateKey(_selectedDate);
      final docId = DateTime.now().millisecondsSinceEpoch.toString();

      String? photoUrl;
      String? storagePath;

      if (_selectedImage != null) {
        storagePath = 'users/$uid/diet/$dateKey/$docId.jpg';
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        await ref.putFile(_selectedImage!);
        photoUrl = await ref.getDownloadURL();
      }

      final data = {
        'date': Timestamp.fromDate(
            DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'dateKey': dateKey,
        'mealType': _mealType,
        'foods': foods,
        'photoUrl': photoUrl,
        'photoPath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'gptTotalKcal': _gptJson?['total_kcal'],
        'gptItems': _gptJson?['items'],
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('diet')
          .doc(dateKey)
          .collection('entries')
          .doc(docId)
          .set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('칼로리와 함께 저장되었습니다.')),
      );

      setState(() {
        _selectedImage = null;
        _foodsController.clear();
        _gptJson = null; // 다음 입력을 위해 초기화
      });
    } catch (e) {
      debugPrint('saveMeal error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== 입력 칩 미리보기 (개별 삭제 가능) =====
  Widget _foodsChipsPreview() {
    final foods = _foodsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (foods.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: foods.map((f) {
          return InputChip(
            label: Text(f),
            onDeleted: () {
              final list = List<String>.from(foods)..remove(f);
              _foodsController.text = list.join(', ');
              _foodsController.selection = TextSelection.fromPosition(
                TextPosition(offset: _foodsController.text.length),
              );
              setState(() {});
            },
          );
        }).toList(),
      ),
    );
  }

  // ===== GPT 결과 뷰 (요약 뱃지 + 로딩바) =====
  Widget _gptResultView() {
    if (_gptJson == null) return const SizedBox.shrink();
    final items = (_gptJson!['items'] as List? ?? []).cast<dynamic>();
    final total = _gptJson!['total_kcal'];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Text(
                  '${total ?? '-'} kcal',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('추정 결과', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((e) {
            final name = e['name'];
            final grams = e['grams'];
            final kcal = e['kcal'];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(name ?? '-')),
                  Text('${grams ?? "?"} g  ·  ${kcal ?? "?"} kcal'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===== UI 파츠 =====
  Widget _mealTypeChips() {
    final types = {
      'breakfast': '아침',
      'lunch': '점심',
      'dinner': '저녁',
      'snack': '간식',
    };
    return Wrap(
      spacing: 8,
      children: types.entries.map((e) {
        final selected = _mealType == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (_) => setState(() => _mealType = e.key),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _dateKey(_selectedDate);
    final foodsText = _foodsController.text.trim();
    final canSave = foodsText.isNotEmpty || _selectedImage != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 식단 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '날짜 선택',
            onPressed: _pickDate,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(dateKey, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== (오늘 총합 칼로리) 헤더 뱃지 =====
            _DailyTotalKcalBadge(date: _selectedDate),

            const SizedBox(height: 12),

            // ===== 사진 카드 =====
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('사진 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, height: 220, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(child: Text('사진을 추가해 주세요')),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('카메라'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('갤러리'),
                        ),
                        if (_selectedImage != null)
                          TextButton.icon(
                            onPressed: () => setState(() => _selectedImage = null),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('삭제'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ===== 기록 + (자동 GPT 포함) 저장 =====
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('기록 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _mealTypeChips(),
                    const SizedBox(height: 12),

                    // 음식 입력
                    TextField(
                      controller: _foodsController,
                      decoration: InputDecoration(
                        labelText: '먹은 음식 쉼표로 구분',
                        border: const OutlineInputBorder(),
                        suffixIcon: (_foodsController.text.isEmpty)
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _foodsController.clear();
                            setState(() {}); // 버튼/칩 상태 갱신
                          },
                        ),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}), // canSave & 칩 업데이트
                    ),
                    _foodsChipsPreview(),

                    // 로딩바 (자동 GPT 진행 시)
                    if (_gptLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 3),
                      ),

                    // GPT 결과 미리보기 (저장 전 자동 호출되면 여기에도 나옴)
                    _gptResultView(),

                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: (_saving || !canSave) ? null : _saveMeal, // ⛳ 저장 = 자동 GPT + 저장
                        icon: _saving
                            ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? '저장 중…' : '저장하기(칼로리 포함)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _TodayEntriesPreview(date: _selectedDate),
          ],
        ),
      ),
    );
  }
}

/// 오늘(선택 날짜)의 총 칼로리 배지
class _DailyTotalKcalBadge extends StatelessWidget {
  final DateTime date;
  const _DailyTotalKcalBadge({required this.date});

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final key = _dateKey(date);

    final q = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('diet').doc(key)
        .collection('entries');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int total = 0;
        for (final d in docs) {
          final t = d.data()['gptTotalKcal'];
          if (t is num) total += t.round();
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '오늘 총합: $total kcal',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 같은 날짜의 기록 + 삭제 기능 포함
class _TodayEntriesPreview extends StatelessWidget {
  final DateTime date;
  const _TodayEntriesPreview({required this.date});

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _confirmAndDelete(BuildContext context, {
    required String uid,
    required String dateKey,
    required String docId,
    String? photoPath,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 식단 기록을 삭제할까요? 사진이 있다면 스토리지에서도 함께 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // 1) Firestore 문서 삭제
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('diet').doc(dateKey)
          .collection('entries').doc(docId)
          .delete();

      // 2) Storage 사진 삭제(있다면)
      if (photoPath != null && photoPath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(photoPath).delete();
        } catch (e) {
          // 사진이 이미 없는 경우도 있으니 조용히 무시
          debugPrint('storage delete skipped: $e');
        }
      }

      // 안내
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다.')),
      );
    } catch (e) {
      debugPrint('delete entry error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final key = _dateKey(date);

    final q = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('diet').doc(key)
        .collection('entries')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('오늘 기록이 없습니다.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘 기록', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...docs.map((d) {
              final data = d.data();
              final foods = (data['foods'] as List?)?.cast<String>() ?? [];
              final mealType = (data['mealType'] as String?) ?? 'meal';
              final photoUrl = (data['photoUrl'] as String?);
              final photoPath = (data['photoPath'] as String?);
              final total = data['gptTotalKcal'];
              final docId = d.id;

              return Dismissible(
                key: ValueKey(docId),
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  // 스와이프 전 확인
                  await _confirmAndDelete(
                    context,
                    uid: uid,
                    dateKey: key,
                    docId: docId,
                    photoPath: photoPath,
                  );
                  // confirmDismiss에서는 false를 반환해서 카드 자체는 직접 제거하지 않음
                  // (StreamBuilder가 최신 상태로 다시 그림)
                  return false;
                },
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: photoUrl == null
                        ? const CircleAvatar(child: Icon(Icons.restaurant))
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(photoUrl, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text({
                            'breakfast': '아침',
                            'lunch': '점심',
                            'dinner': '저녁',
                            'snack': '간식',
                          }[mealType] ?? '식사'),
                        ),
                        if (total != null)
                          Text('$total kcal', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    subtitle: foods.isNotEmpty ? Text('• ${foods.join(", ")}') : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmAndDelete(
                        context,
                        uid: uid,
                        dateKey: key,
                        docId: docId,
                        photoPath: photoPath,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
