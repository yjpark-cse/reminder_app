// medicine_register_page.dart (수정본)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'native_alarm_bridge.dart';

class MedicineRegisterPage extends StatefulWidget {
  final String? docId;                      // users/{uid}/medicines/{docId}
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
  final Set<int> _daysIso = {};      // 1=월요일 ~ 7=일요일
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
        _times.add(TimeOfDay(
          hour: (t['hour'] ?? 0) as int,
          minute: (t['minute'] ?? 0) as int,
        ));
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

  Future<void> _addTime() async {
    final pick = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
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

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    final realUid = auth.currentUser!.uid;
    final medsCol = FirebaseFirestore.instance
        .collection('users').doc(realUid)
        .collection('medicines');

    if (widget.docId == null) {
      // 신규 등록
      final medicineId = DateTime.now().millisecondsSinceEpoch % 1000000;

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

      await medsCol.add({
        'name': name,
        'medicineId': medicineId,
        'times': List.generate(_times.length, (i) {
          final t = _times[i];
          return {'hour': t.hour, 'minute': t.minute, 'slot': i};
        }),
        'daysIso': daysIso,
        'createdAt': Timestamp.now(),
        'ownerUid': realUid,
        'isDeleted': false,
      });
    } else {
      // 수정 저장
      final medicineId =
          _medicineId ?? (DateTime.now().millisecondsSinceEpoch % 1000000);

      await NativeAlarmBridge.cancelByMedicine(medicineId);
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

      await medsCol.doc(widget.docId).set({
        'name': name,
        'medicineId': medicineId,
        'times': List.generate(_times.length, (i) {
          final t = _times[i];
          return {'hour': t.hour, 'minute': t.minute, 'slot': i};
        }),
        'daysIso': daysIso,
        'createdAt': widget.initialData?['createdAt'] ?? Timestamp.now(),
        'ownerUid': realUid,
        'isDeleted': false,
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['월','화','수','목','금','토','일'];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: Text(widget.docId == null ? '약 등록' : '약 수정')),
      // 본문은 스크롤, 버튼은 하단 고정
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "약 이름"),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text("복용 시간: "),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addTime, child: const Text("추가")),
                ],
              ),
              const SizedBox(height: 8),

              // Chip 목록이 2~3줄로 늘어나도 세로 간격 유지
              Wrap(
                spacing: 8,
                runSpacing: 8, // ⬅ 추가: 줄 바뀔 때 세로 간격
                children: List.generate(_times.length, (i) {
                  final t = _times[i];
                  return InputChip(
                    label: Text(t.format(context)),
                    onDeleted: () => _removeTime(i),
                  );
                }),
              ),

              const SizedBox(height: 16),
              const Text('반복 요일', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // ⬇ 키보드 위에 항상 보이는 하단 고정 버튼
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _save,
            child: Text(widget.docId == null ? '저장하기' : '수정 저장'),
          ),
        ),
      ),
    );
  }
}
