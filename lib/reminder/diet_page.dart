import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  // ===== 서버 주소 =====
  // 에뮬레이터: http://10.0.2.2:8787
  // 실기기(같은 Wi-Fi): http://<PC-IP>:8787  (예: http://192.168.0.23:8787)
  static const String BASE_URL = 'http://10.0.2.2:8787';

  final _picker = ImagePicker();
  File? _selectedImage;

  final _foodsController = TextEditingController();
  final _noteController = TextEditingController();

  String _mealType = 'breakfast'; // breakfast | lunch | dinner | snack
  DateTime _selectedDate = DateTime.now();

  bool _saving = false;
  bool _gptLoading = false;
  Map<String, dynamic>? _gptJson; // {items:[{name, grams, kcal}], total_kcal}

  @override
  void dispose() {
    _foodsController.dispose();
    _noteController.dispose();
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

  // ===== 테스트용: 서버 헬스체크 =====
  Future<void> _pingServer() async {
    try {
      final r = await http
          .get(Uri.parse('$BASE_URL/health'))
          .timeout(const Duration(seconds: 5));
      debugPrint('health ${r.statusCode} ${r.body}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('health: ${r.body}')));
    } catch (e) {
      debugPrint('ping error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ping 실패: $e')));
    }
  }

  // ===== 테스트용: 샘플 칼로리 계산 =====
  Future<void> _testCalc() async {
    try {
      final r = await http
          .post(Uri.parse('$BASE_URL/calc-calories'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'foods': '밥 1공기, 김치 조금, 계란말이 1개',
            'mealType': 'lunch',
            'locale': 'ko-KR',
            'units': 'metric',
          }))
          .timeout(const Duration(seconds: 15));
      debugPrint('calc ${r.statusCode} ${r.body}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('calc: ${r.statusCode}')));
    } catch (e) {
      debugPrint('calc error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('calc 실패: $e')));
    }
  }

  // ===== 실제 GPT 칼로리 추정 (사용자 입력 기반) =====
  Future<void> _analyzeFoodsWithGPT() async {
    final foodsText = _foodsController.text.trim();
    if (foodsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먹은 음식을 입력해 주세요. (쉼표로 구분)')),
      );
      return;
    }

    setState(() {
      _gptLoading = true;
      _gptJson = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('$BASE_URL/calc-calories'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "foods": foodsText,
          "mealType": _mealType,
          "locale": "ko-KR",
          "units": "metric"
        }),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() => _gptJson = json);
      } else {
        debugPrint("Server error: ${resp.statusCode} ${resp.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPT 추정 실패(${resp.statusCode}). 서버 로그 확인')),
        );
      }
    } catch (e) {
      debugPrint('gpt analyze error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPT 추정 중 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _gptLoading = false);
    }
  }

  // ===== 저장: Storage 업로드 + Firestore 기록 =====
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

    if (_selectedImage == null && foods.isEmpty && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진이나 음식/메모 중 하나 이상 입력해 주세요.')),
      );
      return;
    }

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
        'note': _noteController.text.trim(),
        'photoUrl': photoUrl,
        'photoPath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (_gptJson != null) ...{
          'gptTotalKcal': _gptJson!['total_kcal'],
          'gptItems': _gptJson!['items'],
        },
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
        const SnackBar(content: Text('기록이 저장되었습니다.')),
      );

      setState(() {
        _selectedImage = null;
        _foodsController.clear();
        _noteController.clear();
        _gptJson = null;
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

  Widget _gptResultView() {
    if (_gptJson == null) return const SizedBox.shrink();
    final items = (_gptJson!['items'] as List? ?? []).cast<dynamic>();
    final total = _gptJson!['total_kcal'];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GPT 추정 총 칼로리: ${total ?? '-'} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...items.map((e) {
            final name = e['name'];
            final grams = e['grams'];
            final kcal = e['kcal'];
            return Text('• $name  (${grams ?? "?"}g)  ≈ ${kcal ?? "?"} kcal');
          }),
          const SizedBox(height: 8),
          Text(
            '※ 참고용 추정치입니다. 실제와 다를 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _dateKey(_selectedDate);
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
            // ===== 연결 테스트 버튼 =====
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pingServer,
                    child: const Text('헬스체크'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testCalc,
                    child: const Text('샘플 계산'),
                  ),
                ),
              ],
            ),
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

            // ===== 기록 + GPT 칼로리 추정 =====
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
                    TextField(
                      controller: _foodsController,
                      decoration: const InputDecoration(
                        labelText: '먹은 음식 (쉼표로 구분: 예) 밥, 김치, 계란말이 1개)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: '메모 (선택)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _gptLoading ? null : _analyzeFoodsWithGPT,
                            icon: _gptLoading
                                ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.analytics_outlined),
                            label: Text(_gptLoading ? '추정 중…' : 'GPT 칼로리 추정'),
                          ),
                        ),
                      ],
                    ),
                    _gptResultView(),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveMeal,
                        icon: _saving
                            ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? '저장 중…' : '저장하기'),
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

/// 같은 날짜의 기록을 미리 보여주는 위젯
class _TodayEntriesPreview extends StatelessWidget {
  final DateTime date;
  const _TodayEntriesPreview({required this.date});

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
              final note = (data['note'] as String?) ?? '';
              final photoUrl = (data['photoUrl'] as String?);
              final total = data['gptTotalKcal'];

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: photoUrl == null
                      ? const CircleAvatar(child: Icon(Icons.restaurant))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(photoUrl, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  title: Row(
                    children: [
                      Text({
                        'breakfast': '아침',
                        'lunch': '점심',
                        'dinner': '저녁',
                        'snack': '간식',
                      }[mealType] ?? '식사'),
                      if (total != null) ...[
                        const SizedBox(width: 8),
                        Text('· ${total} kcal',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]
                    ],
                  ),
                  subtitle: Text([
                    if (foods.isNotEmpty) '• ${foods.join(", ")}',
                    if (note.isNotEmpty) '• $note',
                  ].join('\n')),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
