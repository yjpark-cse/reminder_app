import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Firestore에서 불러온 데이터
  Map<String, int> _waterRecords = {};

  @override
  void initState() {
    super.initState();
    _loadWaterRecords();
  }

  Future<void> _loadWaterRecords() async {
    final snapshot = await FirebaseFirestore.instance.collection('water_records').get();

    Map<String, int> records = {};

    for (var doc in snapshot.docs) {
      records[doc.id] = doc['count'] ?? 0;
    }

    setState(() {
      _waterRecords = records;
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
                String dateKey = "${day.year.toString().padLeft(4, '0')}-"
                    "${day.month.toString().padLeft(2, '0')}-"
                    "${day.day.toString().padLeft(2, '0')}";

                if (_waterRecords.containsKey(dateKey)) {
                  int count = _waterRecords[dateKey]!;
                  return Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: count >= 8 ? Colors.green[300] : Colors.blue[200],
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
          if (_selectedDay != null)
            _buildDetailView(_selectedDay!),
        ],
      ),
    );
  }

  Widget _buildDetailView(DateTime day) {
    String dateKey = "${day.year.toString().padLeft(4, '0')}-"
        "${day.month.toString().padLeft(2, '0')}-"
        "${day.day.toString().padLeft(2, '0')}";

    if (!_waterRecords.containsKey(dateKey)) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("기록이 없습니다."),
      );
    }

    int count = _waterRecords[dateKey]!;

    return Column(
      children: [
        Text(
          "📅 $dateKey",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ListTile(
          title: const Text("물 섭취량"),
          trailing: Text("$count 잔"),
        ),
      ],
    );
  }
}