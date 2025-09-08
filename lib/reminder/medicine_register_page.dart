import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_service.dart';

class MedicineRegisterPage extends StatefulWidget {
  const MedicineRegisterPage({super.key});

  @override
  State<MedicineRegisterPage> createState() => _MedicineRegisterPageState();
}

class _MedicineRegisterPageState extends State<MedicineRegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final List<TimeOfDay> _times = [];
  final Set<String> _selectedDays = {};
  final List<String> _days = ['월', '화', '수', '목', '금', '토', '일'];

  void _addTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && !_times.contains(picked)) {
      setState(() => _times.add(picked));
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    // ✅ 요일은 필수가 아님 (비어 있으면 1회성으로 예약)
    if (name.isEmpty || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("약 이름과 복용 시간을 입력해주세요.")),
      );
      return;
    }

    // 알림 예약
    for (final time in _times) {
      try {
        await scheduleMedicineNotification(
          id: name,
          title: '$name 복용 시간입니다!',
          body: '지금 $name을 복용할 시간이에요.',
          time: time,
          repeatDays: _selectedDays.toList(), // 비어있으면 1회성
        );
      } catch (e) {
        debugPrint("알림 예약 실패: $e");
      }
    }

    // Firebase 저장 (요일이 비어있어도 그대로 저장)
    await FirebaseFirestore.instance.collection('medicines').add({
      'name': name,
      'times': _times.map((t) => t.format(context)).toList(),
      'days': _selectedDays.toList(), // [] 일 수 있음
      'taken': {},
      'createdAt': Timestamp.now(),
    });

    if (mounted) Navigator.pop(context);
  }

  Future<void> _testImmediateNotification() async {
    await NotificationService_showImmediateTest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("약 등록")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "약 이름"),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("복용 시간: "),
                ElevatedButton(onPressed: _addTime, child: const Text("추가")),
              ],
            ),
            Wrap(
              spacing: 10,
              children: _times.map((t) => Chip(label: Text(t.format(context)))).toList(),
            ),
            const SizedBox(height: 12),

            // 요일 선택 (선택 사항)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "반복 요일 (선택) — 선택하지 않으면 1회성 알림으로 등록됩니다.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _days.map((d) {
                final selected = _selectedDays.contains(d);
                return ChoiceChip(
                  label: Text(d),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      selected ? _selectedDays.remove(d) : _selectedDays.add(d);
                    });
                  },
                );
              }).toList(),
            ),

            const Spacer(),

            OutlinedButton(
              onPressed: _testImmediateNotification,
              child: const Text("즉시 알림 테스트"),
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 8),

// ✅ 디버그 버튼 모음 (개발 중에만 쓰세요)
            OutlinedButton(
              onPressed: debugPrintPending,
              child: const Text("현재 예약 목록 보기"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: NotificationService_cancelAll,
              child: const Text("모든 예약 취소"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: debugOneShotIn120s_alarmClock,
              child: const Text("2분 뒤 테스트 알림 예약"),
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _submit,
              child: const Text("저장하기"),
            ),
          ],
        ),
      ),
    );
  }
}
