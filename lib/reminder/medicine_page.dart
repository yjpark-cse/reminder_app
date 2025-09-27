import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'native_alarm_bridge.dart';
import 'medicine_register_page.dart';

String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _hhmmFrom(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

Future<String> _ensureUid() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  return auth.currentUser!.uid;
}

// 오늘 날짜 기준 각 약의 각 슬롯에 대한 체크 상태를 브로드캐스트 스트림으로 제공.
// key: '${docId}_$slot'  value: true/false
Stream<Map<String, bool>> _watchTodayChecks(String uid) {
  final today = _dateKey(DateTime.now());
  return FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('medicines')
      .snapshots()
      .map((qs) {
    final m = <String, bool>{};
    for (final d in qs.docs) {
      final data = d.data();
      final times = (data['times'] as List? ?? const []);
      final taken = (data['taken'] as Map<String, dynamic>?) ?? const {};
      final byDay = (taken[today] as Map?) ?? const {};
      for (final t in times) {
        final slot = (t['slot'] as int?) ?? 0;
        final hour = (t['hour'] as int?) ?? 0;
        final minute = (t['minute'] as int?) ?? 0;
        final hhmm = _hhmmFrom(hour, minute);
        m['${d.id}_$slot'] = byDay[hhmm] == true;
      }
    }
    return m;
  }).asBroadcastStream();
}

// taken.{yyyy-MM-dd}.{HH:mm} = checked 로 저장/해제
Future<void> _setTaken({
  required String uid,
  required String docId,
  required DateTime date,
  required String hhmm,
  required bool checked,
}) async {
  final day = _dateKey(date);
  final doc = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('medicines').doc(docId);

  await doc.set({
    'taken': {
      day: { hhmm: checked }
    }
  }, SetOptions(merge: true));
}

class MedicinePage extends StatefulWidget {
  const MedicinePage({super.key});
  @override
  State<MedicinePage> createState() => _MedicinePageState();
}

class _MedicinePageState extends State<MedicinePage> {
  String? _uid;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = await _ensureUid();
    if (!mounted) return;
    setState(() => _uid = uid);
    _setupMidnightInvalidate();
  }

  // 00:00에 화면 갱신(날짜 바뀔 때 상태가 자동 반영되도록)
  void _setupMidnightInvalidate() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(() {});
      _setupMidnightInvalidate();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _onAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicineRegisterPage()),
    );
  }

  Future<void> _onEdit({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineRegisterPage(
          docId: docId,
          initialData: data,
        ),
      ),
    );
  }

  Future<void> _onDelete({
    required String docId,
    required int medicineId,
    required String name,
  }) async {
    // 알람 전부 취소
    await NativeAlarmBridge.cancelByMedicine(medicineId);
    final uid = _uid!;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('medicines').doc(docId)
        .delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name 삭제 완료')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = _uid!;

    // 약 목록
    final medsStream = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('medicines')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('약 복용 관리')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: medsStream,
        builder: (context, medsSnap) {
          if (medsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final meds = medsSnap.data?.docs ?? [];
          if (meds.isEmpty) {
            return const Center(
              child: Text('등록된 약이 없습니다. 하단 + 버튼으로 등록하세요.'),
            );
          }

          return StreamBuilder<Map<String, bool>>(
            stream: _watchTodayChecks(uid),
            initialData: const {},
            builder: (context, checksSnap) {
              final checks = checksSnap.data ?? {};
              return ListView.separated(
                itemCount: meds.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final doc = meds[i];
                  final m = doc.data();
                  final name = (m['name'] as String?) ?? '약';
                  final medicineId = (m['medicineId'] as int?) ?? 0;
                  final times = (m['times'] as List?) ?? const [];
                  final daysIso = (m['daysIso'] as List?)?.cast<int>() ?? const [];
                  final labels = ['월','화','수','목','금','토','일'];
                  final daysText = daysIso.isEmpty
                      ? '매일'
                      : daysIso.map((d) {
                    final idx = (d - 1).clamp(0, 6);
                    return labels[idx];
                  }).join(',');

                  return ExpansionTile(
                    title: Text(name),
                    subtitle: Text(
                      '$daysText • ${times.map((t){
                        final h=t['hour']??0, mi=t['minute']??0;
                        return TimeOfDay(hour:h, minute:mi).format(context);
                      }).join(', ')}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _onEdit(docId: doc.id, data: m);
                        } else if (v == 'delete') {
                          await _onDelete(
                            docId: doc.id,
                            medicineId: medicineId,
                            name: name,
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('수정')),
                        PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                    children: [
                      for (final t in times)
                        _DoseCheckboxTile(
                          uid: uid,
                          docId: doc.id,
                          label: name,
                          slot: (t['slot'] as int?) ?? 0,
                          hour: (t['hour'] as int?) ?? 0,
                          minute: (t['minute'] as int?) ?? 0,
                          initialChecked:
                          checks['${doc.id}_${(t['slot'] as int?) ?? 0}'] ?? false,
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        icon: const Icon(Icons.add),
        label: const Text('알림 등록'),
      ),
    );
  }
}

class _DoseCheckboxTile extends StatefulWidget {
  final String uid;
  final String docId; // users/{uid}/medicines/{docId}
  final String label;
  final int slot;
  final int hour;
  final int minute;
  final bool initialChecked;

  const _DoseCheckboxTile({
    required this.uid,
    required this.docId,
    required this.label,
    required this.slot,
    required this.hour,
    required this.minute,
    required this.initialChecked,
  });

  @override
  State<_DoseCheckboxTile> createState() => _DoseCheckboxTileState();
}

class _DoseCheckboxTileState extends State<_DoseCheckboxTile> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.initialChecked;
  }

  @override
  void didUpdateWidget(covariant _DoseCheckboxTile old) {
    super.didUpdateWidget(old);
    if (old.initialChecked != widget.initialChecked) {
      _checked = widget.initialChecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText =
    TimeOfDay(hour: widget.hour, minute: widget.minute).format(context);
    final hhmm = _hhmmFrom(widget.hour, widget.minute);

    return CheckboxListTile(
      title: Text('$timeText 복용'),
      value: _checked,
      onChanged: (v) async {
        final val = v ?? false;
        setState(() => _checked = val);
        await _setTaken(
          uid: widget.uid,
          docId: widget.docId,
          date: DateTime.now(),
          hhmm: hhmm,
          checked: val,
        );
      },
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
