import 'package:flutter/material.dart';
import 'native_alarm.dart';

void main() {
  runApp(const AlarmDemoApp());
}

class AlarmDemoApp extends StatelessWidget {
  const AlarmDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '약 복용 알람 데모',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const MedicineAlarmPage(),
    );
  }
}

class MedicineAlarmPage extends StatefulWidget {
  const MedicineAlarmPage({super.key});
  @override
  State<MedicineAlarmPage> createState() => _MedicineAlarmPageState();
}

class _MedicineAlarmPageState extends State<MedicineAlarmPage> {
  TimeOfDay time = const TimeOfDay(hour: 8, minute: 0);
  final TextEditingController labelCtrl = TextEditingController(text: '아침 약');
  final Set<int> days = {1, 2, 3, 4, 5, 6, 7}; // 기본: 매일
  int testId = 1001; // 테스트용 고정 ID

  @override
  void initState() {
    super.initState();
    // 안드 13+ 알림 권한 요청
    NativeAlarm.requestNotificationPermission();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) setState(() => time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dayLabels = const ['월', '화', '수', '목', '금', '토', '일'];

    return Scaffold(
      appBar: AppBar(title: const Text('약 복용 알람 데모')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) 1분 뒤 테스트 버튼
          ElevatedButton.icon(
            icon: const Icon(Icons.timer),
            label: const Text('1분 후 테스트 알림'),
            onPressed: () async {
              final now = TimeOfDay.now();
              // +1분 계산
              int h = now.hour;
              int m = now.minute + 1;
              if (m >= 60) { m -= 60; h = (h + 1) % 24; }

              await NativeAlarm.scheduleAlarm(
                id: testId,
                hour: h,
                minute: m,
                label: '테스트 알림',
                // 빈 리스트: 매일 (한 번 울린 뒤 Receiver가 다음 회차 재예약)
                daysOfWeek: const [],
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('1분 후($h:${m.toString().padLeft(2,'0')}) 알람 예약')),
              );
            },
          ),
          const SizedBox(height: 16),

          // 2) 커스텀 예약 UI
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(
              labelText: '라벨(예: 아침 약)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text('시간: ${time.format(context)}'),
            leading: const Icon(Icons.access_time),
            trailing: const Icon(Icons.edit),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: -8,
            children: List.generate(7, (i) {
              final iso = i + 1; // 1=월 ... 7=일
              final on = days.contains(iso);
              return FilterChip(
                label: Text(dayLabels[i]),
                selected: on,
                onSelected: (_) {
                  setState(() {
                    on ? days.remove(iso) : days.add(iso);
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              // 간단히 ID 고정(여러 개 만들려면 증가시키거나 uuid 사용)
              await NativeAlarm.scheduleAlarm(
                id: 2001,
                hour: time.hour,
                minute: time.minute,
                label: labelCtrl.text.trim().isEmpty ? '약 복용' : labelCtrl.text.trim(),
                daysOfWeek: days.toList()..sort(),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알람 예약 완료 (ID=2001)')),
              );
            },
            child: const Text('예약하기 (ID=2001)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50),
            onPressed: () async {
              await NativeAlarm.cancelAlarm(2001);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알람 취소됨 (ID=2001)')),
              );
            },
            child: const Text('예약 취소 (ID=2001)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final list = await NativeAlarm.listAlarms();
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('예약 목록'),
                  content: SingleChildScrollView(
                    child: Text(
                      list.isEmpty ? '예약 없음' : list.map((e) => e.toString()).join('\n'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('예약 목록 보기'),
          ),
          const SizedBox(height: 24),
          const Text(
            'TIP\n- 1분 후 테스트로 먼저 울리는지 확인하세요.\n'
                '- 제조사 절전 설정이 강하면 setAlarmClock()이라도 간혹 UI 지연될 수 있어요.\n'
                '- Android 13+에서는 알림 권한 허용이 꼭 필요합니다.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
