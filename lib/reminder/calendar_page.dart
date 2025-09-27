import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String? _uid;
  bool _loading = true;

  Map<String, int> _waterRecords = {};
  List<Map<String, dynamic>> _allMedicines = [];
  Map<String, List<Map<String, dynamic>>> _medicineRecords = {};
  Map<String, List<Map<String, dynamic>>> _dietRecords = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _ensureUid();
    await _loadAllRecords();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _ensureUid() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    _uid = auth.currentUser!.uid;
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _hhmmFromTimeMap(Map m) {
    final h = (m['hour'] ?? 0) as int;
    final mi = (m['minute'] ?? 0) as int;
    return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAllRecords() async {
    if (_uid == null) return;
    final fs = FirebaseFirestore.instance;
    final userRef = fs.collection('users').doc(_uid);

    // --- water ---
    final waterSnap = await userRef.collection('water_records').get();
    final waterMap = <String, int>{};
    for (final doc in waterSnap.docs) {
      final data = doc.data();
      waterMap[doc.id] = (data['count'] ?? 0) as int;
    }

    // --- medicines ---
    final medSnap = await userRef.collection('medicines').get();
    final allMeds = <Map<String, dynamic>>[];
    final medMapByDate = <String, List<Map<String, dynamic>>>{};

    for (final doc in medSnap.docs) {
      final data = doc.data();
      final name = data['name'] ?? '약';
      final timesList = List.from(data['times'] ?? const []);
      final timesStr = timesList
          .map<String>((t) => _hhmmFromTimeMap(Map<String, dynamic>.from(t as Map)))
          .toList();
      final days = List<int>.from(data['daysIso'] ?? const []);
      final taken = Map<String, dynamic>.from((data['taken'] ?? {}) as Map);

      allMeds.add({
        'docId': doc.id,
        'name': name,
        'times': timesStr,
        'daysIso': days,
      });

      taken.forEach((dateKey, timeMap) {
        (medMapByDate[dateKey] ??= []).add({
          'docId': doc.id,
          'name': name,
          'times': timesStr,
          'takenMap': Map<String, dynamic>.from(timeMap as Map),
          'daysIso': days,
        });
      });
    }

    // --- diet (entries: 새 스키마 totalKcal 사용) ---
    final dietMap = <String, List<Map<String, dynamic>>>{};
    final entriesSnap = await fs.collectionGroup('entries').get();
    for (final e in entriesSnap.docs) {
      final path = e.reference.path; // users/{uid}/diet/{dateKey}/entries/{id}
      if (!path.startsWith('users/${_uid!}/diet/')) continue;

      final ed = e.data();
      final String dateKey = (ed['dateKey'] as String?) ??
          DateFormat('yyyy-MM-dd').format((ed['date'] as Timestamp).toDate());

      (dietMap[dateKey] ??= []).add({
        'mealType': ed['mealType'] ?? 'meal',
        'foods': (ed['foods'] as List?)?.cast<String>() ?? const <String>[],
        'totalKcal': ed['totalKcal'], // 🔑 단일 키
      });
    }

    setState(() {
      _waterRecords = waterMap;
      _allMedicines = allMeds;
      _medicineRecords = medMapByDate;
      _dietRecords = dietMap;
    });
  }

  bool _hasWater(String dateKey) =>
      _waterRecords.containsKey(dateKey) && (_waterRecords[dateKey] ?? 0) > 0;

  bool _hasTakenMeds(String dateKey) {
    final list = _medicineRecords[dateKey] ?? const [];
    for (final m in list) {
      final takenMap = Map<String, dynamic>.from((m['takenMap'] ?? {}) as Map);
      if (takenMap.values.any((v) => v == true)) return true;
    }
    return false;
  }

  bool _hasDiet(String dateKey) =>
      (_dietRecords[dateKey] ?? const []).isNotEmpty;

  num _sumTotalKcal(List<Map<String, dynamic>> items) {
    num total = 0;
    for (final it in items) {
      final c = it['totalKcal'];
      if (c is int) total += c;
      if (c is double) total += c;
      if (c is String) {
        final parsed = num.tryParse(c);
        if (parsed != null) total += parsed;
      }
    }
    return total;
  }

  String _mealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return '아침';
      case 'lunch':
        return '점심';
      case 'dinner':
        return '저녁';
      case 'snack':
        return '간식';
      default:
        return '식사';
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _loading = true);
    await _loadAllRecords();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("건강 캘린더"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _onRefresh),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dateKey = _dateKey(day);
                final hasWater = _hasWater(dateKey);
                final hasTakenMeds = _hasTakenMeds(dateKey);
                final hasDiet = _hasDiet(dateKey);

                if (hasWater || hasTakenMeds || hasDiet) {
                  final bg = hasTakenMeds
                      ? Colors.green[300]
                      : hasDiet
                      ? Colors.orange[200]
                      : Colors.blue[200];
                  return Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.day}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasWater) const Icon(Icons.opacity, size: 12),
                            if (hasTakenMeds) const Icon(Icons.verified, size: 12),
                            if (hasDiet) const Icon(Icons.restaurant, size: 12),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('날짜를 선택해 주세요.'))
                : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                children: [_buildDetailView(_selectedDay!)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(DateTime day) {
    final dateKey = _dateKey(day);
    final water = _waterRecords[dateKey];
    final takenMeds = _takenMedsForDay(dateKey);
    final diet = _dietRecords[dateKey];

    if (water == null && (diet == null || diet.isEmpty) && takenMeds.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(8),
        child: const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text("기록이 없습니다."),
          subtitle: Text("물/약 복용/식단을 기록하면 이곳에 표시됩니다."),
        ),
      );
    }

    final tiles = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ];

    // 물
    if (water != null) {
      tiles.add(Card(
        child: ListTile(
          leading: const Icon(Icons.opacity),
          title: const Text("물 섭취량"),
          trailing: Text("$water 잔"),
        ),
      ));
    }

    // 약 (읽기 전용)
    if (takenMeds.isNotEmpty) {
      tiles.addAll(takenMeds.map((m) {
        final times = List<String>.from((m['times'] ?? const []) as List);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.medication),
            title: Text(m['name'] ?? '약'),
            subtitle: times.isEmpty
                ? const Text('복용 완료 기록이 없습니다.')
                : Wrap(
              spacing: 6,
              runSpacing: -6,
              children: times
                  .map((t) => Chip(
                label: Text(t),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ))
                  .toList(),
            ),
          ),
        );
      }));
    }

    // 식단
    if (diet != null && diet.isNotEmpty) {
      final total = _sumTotalKcal(diet);
      tiles.add(
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.restaurant),
            title: const Text('식단'),
            subtitle: Text('총 칼로리: $total kcal · ${diet.length}건'),
            childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            children: [
              const SizedBox(height: 4),
              ...diet.map((it) {
                final mealType = (it['mealType'] as String?) ?? 'meal';
                final foods = (it['foods'] as List?)?.cast<String>() ?? const <String>[];
                final cal = it['totalKcal'];
                String kcal = '';
                if (cal is num) {
                  kcal = '${cal.toStringAsFixed(0)} kcal';
                } else if (cal is String && cal.isNotEmpty) {
                  kcal = '$cal kcal';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _mealLabel(mealType),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (kcal.isNotEmpty) Text(kcal),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (foods.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children: foods
                              .map((f) => Chip(
                            label: Text(f),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                          ))
                              .toList(),
                        )
                      else
                        const Text('기록된 음식이 없습니다.',
                            style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tiles);
  }

  List<Map<String, dynamic>> _takenMedsForDay(String dateKey) {
    final list = _medicineRecords[dateKey] ?? const [];
    final result = <Map<String, dynamic>>[];
    for (final m in list) {
      final name = m['name'];
      final times = List<String>.from((m['times'] ?? const []) as List);
      final takenMap = Map<String, dynamic>.from((m['takenMap'] ?? {}) as Map);
      final takenTimes = times.where((t) => takenMap[t] == true).toList();
      if (takenTimes.isNotEmpty) {
        result.add({'docId': m['docId'], 'name': name, 'times': takenTimes});
      }
    }
    return result;
  }
}
