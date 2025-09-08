import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'native_alarm_bridge.dart';
import 'medicine_register_page.dart';

String _ymd(DateTime d) => DateFormat('yyyyMMdd').format(d);

Future<String> _ensureUid() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) await auth.signInAnonymously();
  return auth.currentUser!.uid;
}

/// 오늘 날짜의 체크 상태를 '브로드캐스트' 스트림으로 제공 (중복 구독 안전)
Stream<Map<String, bool>> _watchTodayChecks(String uid) {
  final day = _ymd(DateTime.now());
  return FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('intakes').doc(day)
      .collection('items')
      .snapshots()
      .map((qs) {
    final m = <String, bool>{};
    for (final d in qs.docs) {
      m[d.id] = (d.data()['checked'] as bool?) ?? false;
    }
    return m;
  })
      .asBroadcastStream(); // ✅ 여러 구독 허용
}

Future<void> _setCheckedToday({
  required String uid,
  required int medicineId,
  required int slot,
  required String label,
  required bool checked,
  DateTime? date,
}) async {
  final day = _ymd(date ?? DateTime.now());
  final doc = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('intakes').doc(day)
      .collection('items').doc('${medicineId}_$slot');
  await doc.set({
    'medicineId': medicineId,
    'slot': slot,
    'label': label,
    'checked': checked,
    'date': day,
    'updatedAt': FieldValue.serverTimestamp(),
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

  /// 00:00에 화면 갱신(오늘 경로가 바뀌므로 스트림도 자연히 갈아탄다)
  void _setupMidnightInvalidate() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(() {}); // rebuild
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
    await NativeAlarmBridge.cancelByMedicine(medicineId);      // 네이티브 알람 전부 취소
    await FirebaseFirestore.instance.collection('medicines').doc(docId).delete(); // 문서 삭제
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 삭제 완료')));
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = _uid!;

    // Firestore: 등록된 약 리스트
    final medsStream = FirebaseFirestore.instance
        .collection('medicines')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('약 복용 관리')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: medsStream, // ✅ 매 빌드마다 같은 참조지만 Firestore가 브로드캐스트 스트림 제공
        builder: (context, medsSnap) {
          if (medsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final meds = medsSnap.data?.docs ?? [];
          if (meds.isEmpty) {
            return const Center(child: Text('등록된 약이 없습니다. 하단 + 버튼으로 등록하세요.'));
          }

          // ✅ 체크 스트림은 함수 호출로 바로 전달 (중복 구독 안전)
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
                  final daysText = daysIso.isEmpty
                      ? '매일'
                      : daysIso.map((d) => ['월','화','수','목','금','토','일'][d-1]).join(',');

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
                          await _onDelete(docId: doc.id, medicineId: medicineId, name: name);
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
                          medicineId: medicineId,
                          label: name,
                          slot: (t['slot'] as int?) ?? 0,
                          hour: (t['hour'] as int?) ?? 0,
                          minute: (t['minute'] as int?) ?? 0,
                          initialChecked: checks['${medicineId}_${t['slot']}'] ?? false,
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
  final int medicineId;
  final String label;
  final int slot;
  final int hour;
  final int minute;
  final bool initialChecked;

  const _DoseCheckboxTile({
    required this.uid,
    required this.medicineId,
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
    final timeText = TimeOfDay(hour: widget.hour, minute: widget.minute).format(context);
    return CheckboxListTile(
      title: Text('$timeText 복용'),
      value: _checked,
      onChanged: (v) async {
        final val = v ?? false;
        setState(() => _checked = val);
        await _setCheckedToday(
          uid: widget.uid,
          medicineId: widget.medicineId,
          slot: widget.slot,
          label: widget.label,
          checked: val,
        );
      },
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
