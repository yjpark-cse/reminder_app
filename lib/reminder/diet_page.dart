import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  final _foodsController = TextEditingController();
  final _manualKcalC = TextEditingController(); // 총 칼로리(수동/AI 버튼으로 채움)

  String _mealType = 'breakfast'; // breakfast | lunch | dinner | snack
  DateTime _selectedDate = DateTime.now();

  bool _saving = false;
  bool _aiLoading = false;
  bool _totalFromAI = false; // 총칼로리가 AI로 채워졌는지 표시

  @override
  void dispose() {
    _foodsController.dispose();
    _manualKcalC.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
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

  // ===== [AI로 채우기] — 서버 호출해서 total_kcal을 칼로리 입력란에 채움 =====
  Future<void> _runAiEstimation() async {
    final foodsText = _foodsController.text.trim();
    if (foodsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먹은 음식을 먼저 입력해 주세요.')),
      );
      return;
    }

    setState(() => _aiLoading = true);
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
        final total = (json['total_kcal'] as num?)?.round();
        if (total == null) throw '모델이 total_kcal을 반환하지 않았습니다.';

        setState(() {
          _manualKcalC.text = total.toString(); // 입력칸 자동 채움
          _totalFromAI = true; // 출처 표시
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 추정: 약 $total kcal')),
        );
      } else {
        throw 'HTTP ${resp.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 추정 실패: $e\n직접 칼로리를 입력해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  // ===== 저장: 총칼로리 입력란의 숫자만 사용 =====
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
        : foodsText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음식 입력이 필요합니다.')),
      );
      return;
    }

    final totalKcal = int.tryParse(_manualKcalC.text.trim());
    if (totalKcal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('총 칼로리를 입력하거나, “AI로 채우기”를 눌러 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dateKey = _dateKey(_selectedDate);
      final docId = DateTime.now().millisecondsSinceEpoch.toString();

      final data = {
        'date': Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'dateKey': dateKey,
        'mealType': _mealType,
        'foods': foods,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // 단일 키 스키마
        'totalKcal': totalKcal,
        'kcalSource': _totalFromAI ? 'ai' : 'manual',
      };

      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('diet').doc(dateKey)
          .collection('entries').doc(docId)
          .set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$totalKcal kcal로 저장되었습니다.')),
      );

      setState(() {
        _foodsController.clear();
        _manualKcalC.clear();
        _totalFromAI = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== 입력 칩 미리보기 =====
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
    final canSave = foodsText.isNotEmpty;

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
            // 오늘 총합 배지
            _DailyTotalKcalBadge(date: _selectedDate),

            const SizedBox(height: 12),

            // 기록 카드
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
                      decoration: InputDecoration(
                        labelText: '먹은 음식',
                        hintText: '먹은 음식 쉼표로 구분',
                        border: const OutlineInputBorder(),
                        suffixIcon: (_foodsController.text.isEmpty)
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _foodsController.clear();
                            setState(() {});
                          },
                        ),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _foodsChipsPreview(),
                    const SizedBox(height: 16), // 3) 총 칼로리 입력 (suffix에 "AI로 채우기", helperText에 상태)
                    TextField(
                      controller: _manualKcalC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: InputDecoration(
                        labelText: '총 칼로리',
                        hintText: '예: 350',
                        border: const OutlineInputBorder(),
                        suffix: TextButton(
                          onPressed: _aiLoading ? null : _runAiEstimation,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _aiLoading
                              ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('AI로 채우기'),
                        ),
                        helperText: _totalFromAI ? 'AI 적용됨' : null,
                        helperStyle: Theme.of(context).textTheme.labelSmall,
                      ),
                      onChanged: (_) {
                        if (_totalFromAI) setState(() => _totalFromAI = false);
                      },
                    ),
                    const SizedBox(height: 20), // 4) 저장 버튼(전체 폭)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: (_saving || _foodsController.text.trim().isEmpty) ? null : _saveMeal,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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

/// 오늘(선택 날짜)의 총 칼로리 배지 — totalKcal만 사용
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
          final t = d.data()['totalKcal'];
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

/// 같은 날짜의 기록 + 삭제 기능 — totalKcal만 사용
class _TodayEntriesPreview extends StatelessWidget {
  final DateTime date;
  const _TodayEntriesPreview({required this.date});

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _confirmAndDelete(
      BuildContext context, {
        required String uid,
        required String dateKey,
        required String docId,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 식단 기록을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('diet').doc(dateKey)
          .collection('entries').doc(docId)
          .delete();

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
              final total = data['totalKcal'];
              final docId = d.id;
              final source = (data['kcalSource'] as String?); // manual | ai

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
                  await _confirmAndDelete(
                    context,
                    uid: uid,
                    dateKey: key,
                    docId: docId,
                  );
                  return false; // StreamBuilder가 다시 그림
                },
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.restaurant)),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text({
                            'breakfast': '아침',
                            'lunch': '점심',
                            'dinner': '저녁',
                            'snack': '간식',
                          }[mealType] ??
                              '식사'),
                        ),
                        if (total != null)
                          Row(
                            children: [
                              Text('$total kcal', style: Theme.of(context).textTheme.bodySmall),
                              if (source != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                  ),
                                  child: Text(
                                    source == 'ai' ? 'AI' : '수동',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
