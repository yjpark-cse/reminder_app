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

class _WaterPageState extends State<WaterPage> with WidgetsBindingObserver {
  int _counter = 0;
  int _goal = 8; // 기본 목표 8잔
  String? _uid;
  Timer? _midnightTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  String _todayKey([DateTime? dt]) =>
      DateFormat('yyyy-MM-dd').format(dt ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.widgetClicked.listen((_) => _loadAll());
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _docSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAll(); // 앱 복귀 시 위젯값 반영 + Firestore 동기화
    }
  }

  Future<void> _init() async {
    await _ensureUid();
    await _loadAll();
    _listenTodayDoc();          // Firestore 실시간 구독(다운그레이드 방지 가드 포함)
    _scheduleMidnightReset();
  }

  Future<void> _ensureUid() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    _uid = auth.currentUser!.uid;

    // 위젯 백그라운드 콜백이 Firestore에 쓰지 않더라도, 향후 확장 대비 uid 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', _uid!);
  }

  /// Firestore 오늘 문서 실시간 리스너 → 앱/위젯 동기화
  /// 단, 더 낮은 값으로는 덮어쓰지 않도록 가드
  void _listenTodayDoc() {
    if (_uid == null) return;
    _docSub?.cancel();

    final today = _todayKey();
    _docSub = FirebaseFirestore.instance
        .collection('users').doc(_uid)
        .collection('water_records').doc(today)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;
      final fsCount = (data['count'] ?? _counter) as int;
      final fsGoal  = (data['goal']  ?? _goal) as int;

      // ↓ 현재 앱 화면의 _counter보다 Firestore가 작으면 무시(다운그레이드 방지)
      if (fsCount < _counter) return;

      if (!mounted) return;
      setState(() {
        _counter = fsCount;
        _goal = fsGoal;
      });

      // 위젯도 최신 상태로
      await HomeWidget.saveWidgetData<int>('_counter', _counter);
      await HomeWidget.updateWidget(name: 'WidgetProvider');
    });
  }

  // 앱 실행/재개 시: Prefs/Widget/Firestore를 병합해서 현재값 반영
  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    _goal = prefs.getInt('water_goal') ?? 8;
    final today = _todayKey();
    final lastDate = prefs.getString('last_water_date');

    // 자정 지나면 0으로 초기화
    if (lastDate != today) {
      await _writeCountAndSync(0);
      await prefs.setString('last_water_date', today);
      return;
    }

    // 1) 각각의 소스 읽기
    final widgetCounter =
        await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0) ?? 0;

    int? fsCount, fsGoal;
    if (_uid != null) {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('water_records').doc(today)
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        fsCount = data['count'] as int?;
        fsGoal  = data['goal']  as int?;
      }
    }

    // 2) 병합 규칙: 최종 카운트는 더 큰 값(방금 위젯에서 눌렀다면 widgetCounter가 큼)
    final int finalCount = (fsCount == null)
        ? widgetCounter
        : (widgetCounter > fsCount ? widgetCounter : fsCount);

    // 목표는 Firestore에 있으면 우선
    if (fsGoal != null) _goal = fsGoal;

    // 3) Firestore/위젯 되돌려쓰기(싱크 맞춤)
    if (_uid != null && (fsCount == null || finalCount != fsCount)) {
      await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('water_records').doc(today)
          .set({
        'count': finalCount,
        'goal': _goal,
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerUid': _uid,
      }, SetOptions(merge: true));
    }
    if (finalCount != widgetCounter) {
      await HomeWidget.saveWidgetData<int>('_counter', finalCount);
      await HomeWidget.updateWidget(name: 'WidgetProvider');
    }

    // 4) 상태 반영 + 로컬 저장
    _counter = finalCount;
    if (mounted) setState(() {});
    await prefs.setInt('_counter', _counter);
    await prefs.setInt('water_goal', _goal);
    await prefs.setString('last_water_date', today);
  }

  // 자정 리셋: 00:00에 0으로 저장 + 위젯/Firestore 반영
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () async {
      await _writeCountAndSync(0);
      _scheduleMidnightReset();
    });
  }

  /// 공통 쓰기: Firestore → 위젯 → 로컬 Prefs 순서 (단일 진실 소스 = Firestore)
  Future<void> _writeCountAndSync(int newCount) async {
    _counter = newCount;
    if (mounted) setState(() {});

    final today = _todayKey();

    // 1) Firestore 기록 (필드명 유지)
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

    // 2) 위젯 저장 & 갱신
    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.updateWidget(name: 'WidgetProvider');

    // 3) 로컬 Prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('_counter', _counter);
    await prefs.setInt('water_goal', _goal);
    await prefs.setString('last_water_date', today);
  }

  // 기존 API와의 호환을 위해 남겨두되, 내부는 공통 함수 호출
  Future<void> updateAppWidget() async {
    await _writeCountAndSync(_counter);
  }

  void _incrementCounter() => _writeCountAndSync(_counter + 1);

  void _decrementCounter() {
    if (_counter > 0) _writeCountAndSync(_counter - 1);
  }

  Future<void> _updateGoal(int newGoal) async {
    _goal = newGoal;
    if (mounted) setState(() {});
    final today = _todayKey();

    if (_uid != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('water_records').doc(today)
          .set({
        'goal': _goal,
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerUid': _uid,
      }, SetOptions(merge: true));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', _goal);

    await HomeWidget.updateWidget(name: 'WidgetProvider');
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
                await _updateGoal(input);
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
    final progress = (_goal > 0) ? (_counter / _goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[200],
        title: const Text('오늘의 수분 섭취', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showGoalDialog),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('오늘 마신 물의 양', style: Theme.of(context).textTheme.titleMedium),
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
                    borderRadius: BorderRadius.circular(20),
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
