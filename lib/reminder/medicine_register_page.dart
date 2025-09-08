import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'native_alarm_bridge.dart';

class MedicineRegisterPage extends StatefulWidget {
  /// 수정 모드면 두 값을 함께 전달
  final String? docId;                      // medicines 문서 ID
  final Map<String, dynamic>? initialData;  // {name, medicineId, times, daysIso, createdAt}

  const MedicineRegisterPage({
    super.key,
    this.docId,
    this.initialData,
  });

  @override
  State<MedicineRegisterPage> createState() => _MedicineRegisterPageState();
}

class _MedicineRegisterPageState extends State<MedicineRegisterPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final List<TimeOfDay> _times = []; // 여러 복용 시간
  final Set<int> _daysIso = {};      // 1=Mon..7=Sun
  int? _medicineId;                  // 수정 모드에서 사용

  @override
  void initState() {
    super.initState();
    final m = widget.initialData;
    if (m != null) {
      _nameCtrl.text = m['name'] ?? '';
      _medicineId = m['medicineId'] as int?;
      final times = (m['times'] as List?) ?? const [];
      for (final t in times) {
        _times.add(TimeOfDay(hour: t['hour'] ?? 0, minute: t['minute'] ?? 0));
      }
      final di = (m['daysIso'] as List?)?.cast<int>() ?? const [];
      _daysIso.addAll(di);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addTime() async {
    final pick = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pick != null && !_times.contains(pick)) {
      setState(() => _times.add(pick));
    }
  }

  void _removeTime(int index) {
    setState(() => _times.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("약 이름과 복용 시간을 입력하세요.")),
      );
      return;
    }
    final daysIso = _daysIso.toList()..sort();

    await NativeAlarmBridge.requestNotificationPermission();

    if (widget.docId == null) {
      // 신규 등록
      final medicineId = DateTime.now().millisecondsSinceEpoch % 1000000;

      // 슬롯별 네이티브 예약 (slot 0..n-1)
      for (var slot = 0; slot < _times.length; slot++) {
        final t = _times[slot];
        await NativeAlarmBridge.scheduleAlarm(
          id: medicineId * 100 + slot,
          hour: t.hour,
          minute: t.minute,
          label: name,
          daysOfWeek: daysIso,
        );
      }

      // Firestore 문서 생성
      await FirebaseFirestore.instance.collection('medicines').add({
        'name': name,
        'medicineId': medicineId,
        'times': List.generate(_times.length, (i) {
          final t = _times[i];
          return {'hour': t.hour, 'minute': t.minute, 'slot': i};
        }),
        'daysIso': daysIso,
        'createdAt': Timestamp.now(),
      });
    } else {
      // 수정 저장
      final medicineId = _medicineId ?? (DateTime.now().millisecondsSinceEpoch % 1000000);

      // 기존 슬롯 알람 전부 취소
      await NativeAlarmBridge.cancelByMedicine(medicineId);

      // 현재 입력값 기준 재예약
      for (var slot = 0; slot < _times.length; slot++) {
        final t = _times[slot];
        await NativeAlarmBridge.scheduleAlarm(
          id: medicineId * 100 + slot,
          hour: t.hour,
          minute: t.minute,
          label: name,
          daysOfWeek: daysIso,
        );
      }

      // Firestore 문서 갱신
      await FirebaseFirestore.instance.collection('medicines').doc(widget.docId).set({
        'name': name,
        'medicineId': medicineId,
        'times': List.generate(_times.length, (i) {
          final t = _times[i];
          return {'hour': t.hour, 'minute': t.minute, 'slot': i};
        }),
        'daysIso': daysIso,
        'createdAt': widget.initialData?['createdAt'] ?? Timestamp.now(),
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['월','화','수','목','금','토','일'];
    return Scaffold(
      appBar: AppBar(title: Text(widget.docId == null ? '약 등록' : '약 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
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
              spacing: 8,
              children: List.generate(_times.length, (i) {
                final t = _times[i];
                return InputChip(
                  label: Text(t.format(context)),
                  onDeleted: () => _removeTime(i),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('반복 요일', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final iso = i + 1;
                final sel = _daysIso.contains(iso);
                return ChoiceChip(
                  label: Text(dayLabels[i]),
                  selected: sel,
                  onSelected: (_) {
                    setState(() {
                      sel ? _daysIso.remove(iso) : _daysIso.add(iso);
                    });
                  },
                );
              }),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _save,
              child: Text(widget.docId == null ? '저장하기' : '수정 저장'),
            ),
          ],
        ),
      ),
    );
  }
}
