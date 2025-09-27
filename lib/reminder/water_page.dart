import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  int _counter = 0;
  int _goal = 8; // 기본 목표 8잔
  String? _uid;
  Timer? _midnightTimer;

  String _todayKey([DateTime? dt]) =>
      DateFormat('yyyy-MM-dd').format(dt ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => _loadAll());
    _init();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureUid();
    await _loadAll();
    _scheduleMidnightReset(); // 자정 리셋 타이머
  }

  Future<void> _ensureUid() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    _uid = auth.currentUser!.uid;
  }

  // 앱 실행 시/재개 시 호출: Prefs/Widget/Firestore를 동기화해서 현재값 반영
  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // 목표 불러오기
    _goal = prefs.getInt('water_goal') ?? 8;

    // 오늘 키
    final today = _todayKey();

    // 지난 날짜면 0으로 초기화(앱이 꺼져있던 동안 자정이 지난 경우)
    final lastDate = prefs.getString('last_water_date');
    if (lastDate != today) {
      _counter = 0;
      await prefs.setString('last_water_date', today);
      await HomeWidget.saveWidgetData<int>('_counter', _counter);
      if (_uid != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(_uid)
            .collection('water_records').doc(today)
            .set({
          'count': _counter,
          'goal': _goal,
          'updatedAt': FieldValue.serverTimestamp(),
          'ownerUid': _uid,
        }, SetOptions(merge: true));
      }
      setState(() {});
      return;
    }

    // 위젯 저장소에서 카운터 가져오기
    final widgetCounter =
        await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0) ?? 0;
    _counter = widgetCounter;

    // 유저별 Firestore에 저장된 오늘 기록이 있으면 우선 적용(동기화)
    if (_uid != null) {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('water_records').doc(today)
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        _counter = (data['count'] ?? _counter) as int;
        _goal = (data['goal'] ?? _goal) as int;
      }
    }

    setState(() {});
  }

  // 자정 리셋 타이머: 00:00에 0으로 저장 + 위젯, Firestore 반영
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () async {
      _counter = 0;
      setState(() {});
      await updateAppWidget();
      _scheduleMidnightReset(); // 다음 자정 예약
    });
  }

  Future<void> updateAppWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    await prefs.setInt('water_goal', _goal);
    await prefs.setString('last_water_date', today);
    await prefs.setInt('_counter', _counter);

    // HomeWidget 저장 및 새로고침
    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.updateWidget(name: 'WidgetProvider');

    // Firestore (users/{uid}/water_records/{yyyy-MM-dd})
    if (_uid != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('water_records').doc(today)
          .set({
        'count': _counter,
        'goal': _goal,
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerUid': _uid,
      }, SetOptions(merge: true));
    }
  }

  void _incrementCounter() {
    setState(() => _counter++);
    updateAppWidget();
  }

  void _decrementCounter() {
    if (_counter > 0) {
      setState(() => _counter--);
      updateAppWidget();
    }
  }

  void _showGoalDialog() {
    final TextEditingController goalController =
    TextEditingController(text: '$_goal');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('하루 물 목표량 설정'),
        content: TextField(
          controller: goalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '목표 잔 수'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = int.tryParse(goalController.text);
              if (input != null && input > 0) {
                setState(() => _goal = input);
                await updateAppWidget(); // 목표 변경도 동기화
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress =
    (_goal > 0) ? (_counter / _goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[200],
        title: const Text(
          '오늘의 수분 섭취',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showGoalDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 메인 수분 섭취 내용
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('오늘 마신 물의 양',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text(
                    '$_counter / $_goal 잔',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: Colors.blue[800]),
                  ),
                  const SizedBox(height: 30),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20), // 테두리 둥글게
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[300],
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('${(progress * 100).toInt()}% 달성'),
                ],
              ),
            ),
          ),

          // 오른쪽 하단에 위(+), 아래(-) 버튼
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0, bottom: 30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'increase',
                    backgroundColor: Colors.blue[300],
                    onPressed: _incrementCounter,
                    tooltip: '물 한 잔 추가',
                    child: const Icon(Icons.water_drop),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'decrease',
                    backgroundColor: Colors.yellow[300],
                    onPressed: _decrementCounter,
                    tooltip: '물 한 잔 감소',
                    child: const Icon(Icons.water_drop_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
