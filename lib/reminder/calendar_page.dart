import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, int> _waterRecords = {};
  Map<String, List<Map<String, dynamic>>> _medicineRecords = {};

  @override
  void initState() {
    super.initState();
    _loadAllRecords();
  }

  Future<void> _loadAllRecords() async {
    final waterSnap = await FirebaseFirestore.instance.collection('water_records').get();
    final medicineSnap = await FirebaseFirestore.instance.collection('medicines').get();

    Map<String, int> waterMap = {};
    Map<String, List<Map<String, dynamic>>> medMap = {};

    for (var doc in waterSnap.docs) {
      waterMap[doc.id] = doc['count'] ?? 0;
    }

    for (var doc in medicineSnap.docs) {
      final data = doc.data();
      final name = data['name'];
      final times = data['times'];
      final taken = data['taken'] ?? {};

      taken.forEach((dateStr, timeMap) {
        final record = {
          'name': name,
          'times': times,
          'takenMap': timeMap,
        };
        if (!medMap.containsKey(dateStr)) {
          medMap[dateStr] = [];
        }
        medMap[dateStr]!.add(record);
      });
    }

    setState(() {
      _waterRecords = waterMap;
      _medicineRecords = medMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("건강 캘린더")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                String dateKey = DateFormat('yyyy-MM-dd').format(day);
                bool hasWater = _waterRecords.containsKey(dateKey);
                bool hasMedicine = _medicineRecords.containsKey(dateKey);
                bool allTaken = false;

                if (hasMedicine) {
                  final meds = _medicineRecords[dateKey]!;
                  allTaken = meds.every((m) {
                    final takenMap = m['takenMap'] as Map<String, dynamic>;
                    return takenMap.values.every((v) => v == true);
                  });
                }

                if (hasWater || hasMedicine) {
                  return Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: allTaken
                          ? Colors.green[300]
                          : (hasMedicine ? Colors.red[200] : Colors.blue[200]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text('${day.day}'),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null) _buildDetailView(_selectedDay!),
        ],
      ),
    );
  }

  Widget _buildDetailView(DateTime day) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    final water = _waterRecords[dateKey];
    final meds = _medicineRecords[dateKey];

    if (water == null && meds == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("기록이 없습니다."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("   $dateKey", style: const TextStyle(fontWeight: FontWeight.bold)),
        if (water != null)
          ListTile(
            title: const Text("물 섭취량"),
            trailing: Text("$water 잔"),
          ),
        if (meds != null) ...meds.map((m) {
          final takenMap = m['takenMap'] as Map<String, dynamic>;
          final times = m['times'] as List;
          return ExpansionTile(
            title: Text(m['name']),
            children: times.map<Widget>((t) {
              final taken = takenMap[t] ?? false;
              return ListTile(
                leading: const Icon(Icons.access_time),
                title: Text("복용 시간: $t"),
                trailing: Text(
                  taken ? "복용 완료" : "미복용",
                  style: TextStyle(
                    color: taken ? Colors.green : Colors.red,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}
