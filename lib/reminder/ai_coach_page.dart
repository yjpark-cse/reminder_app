import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'profile.dart';

class AICoachPage extends StatefulWidget {
  const AICoachPage({super.key});

  @override
  State<AICoachPage> createState() => _AICoachPageState();
}

class _AICoachPageState extends State<AICoachPage> with WidgetsBindingObserver {
  // AI 영역
  String _dailyMessage = "불러오는 중...";
  String _dailyChallenge = "불러오는 중...";
  bool _challengeDone = false;

  // 요약 상태
  double? _tdee;                 // 권장 칼로리 (프로필 기반)
  double? _todayCalories = 0;    // 오늘 섭취 칼로리 합 (실시간, 기본 0)

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late final ProfileRepository _profileRepo;

  // 구독/키
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _calorieSub;
  StreamSubscription<User?>? _authSub;
  String? _currentDietKey;   // yyyy-MM-dd
  String? _currentUid;       // 리스너가 붙어있는 uid
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileRepo = ProfileRepository(_db);

    _fetchDailyMessage();
    _fetchDailyChallenge();

    // 로그인 상태가 준비되면 세팅
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      await _loadProfileAndTDEE();
      await _setupLiveCalorieListener(force: true);
    });

    // 앱 시작 시에도 한 번 시도 (이미 로그인되어 있을 수 있음)
    Future.microtask(() async {
      if (_auth.currentUser != null) {
        await _loadProfileAndTDEE();
        await _setupLiveCalorieListener(force: true);
      }
    });

    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calorieSub?.cancel();
    _authSub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  String _todayKey([DateTime? dt]) =>
      DateFormat('yyyy-MM-dd').format(dt ?? DateTime.now());

  // 자정에 날짜 키 갱신 & 리스너 재설정
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1); // 내일 00:00
    final diff = next.difference(now);
    _midnightTimer = Timer(diff, () async {
      if (!mounted) return;
      _currentDietKey = null;
      _todayCalories = 0;
      setState(() {});
      await _setupLiveCalorieListener(force: true);
      _scheduleMidnightRefresh(); // 다음 날도 예약
    });
  }

  // AI 호출/캐시
  Future<String> _callAICoach(String type, {dynamic data, String? userName}) async {
    final response = await http.post(
      Uri.parse("$serverUrl/ai-coach"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"type": type, "data": data, "userName": userName}),
    );
    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      return res["message"] ?? "AI 응답 없음";
    } else {
      return "AI 서버 호출 실패 (${response.statusCode})";
    }
  }

  Future<String> _getDailyCached(String field, String type) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return "로그인 필요";

    final todayKey = _todayKey();
    final docRef = _db.collection('users').doc(uid).collection('ai_coach').doc(todayKey);

    final snap = await docRef.get();
    if (snap.exists && snap.data()?[field] != null) {
      return snap.data()![field];
    }

    final result = await _callAICoach(type, userName: uid);
    await docRef.set({field: result}, SetOptions(merge: true));
    return result;
  }

  Future<void> _fetchDailyMessage() async {
    final msg = await _getDailyCached("dailyMessage", "dailyMessage");
    if (!mounted) return;
    setState(() => _dailyMessage = msg);
  }

  Future<void> _fetchDailyChallenge() async {
    final challenge = await _getDailyCached("dailyChallenge", "dailyChallenge");
    if (!mounted) return;
    setState(() => _dailyChallenge = challenge);
  }

  //프로필 & TDEE
  Future<void> _loadProfileAndTDEE() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      UserProfile? p = await _profileRepo.loadCached();
      p ??= await _profileRepo.fetchFromFirestore(uid);

      if (p != null) {
        await _profileRepo.cacheLocal(p);
        if (!mounted) return;
        setState(() {
          _tdee = p!.tdee; // UserProfile.tdee에 계산 포함
        });
      } else {
        if (!mounted) return;
        setState(() => _tdee = null);
      }
    } catch (e) {
      debugPrint('loadProfileAndTDEE error: $e');
    }
  }

  // 실시간 총 칼로리 리스너
  Future<void> _setupLiveCalorieListener({bool force = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final key = _todayKey();

    // 이미 같은 uid + 같은 날짜면 생략
    if (!force && _currentUid == uid && _currentDietKey == key && _calorieSub != null) {
      return;
    }

    await _calorieSub?.cancel();
    _currentUid = uid;
    _currentDietKey = key;

    final col = _db
        .collection('users').doc(uid)
        .collection('diet').doc(key)
        .collection('entries');

    _calorieSub = col.snapshots().listen((snap) {
      double sum = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final n = data['totalKcal'];
        if (n is num) sum += n.toDouble();
      }
      if (mounted) {
        setState(() => _todayCalories = sum);
      }
    }, onError: (e) {
      debugPrint('calorie snapshots error: $e');
    });
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final kcalDelta = (_tdee != null && _todayCalories != null)
        ? (_tdee! - _todayCalories!).round()
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text("AI 코치")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 오늘의 메시지
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("<오늘의 활력 메시지>",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_dailyMessage, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 데일리 챌린지
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("<오늘의 챌린지>",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_dailyChallenge, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _challengeDone = !_challengeDone),
                      icon: Icon(_challengeDone ? Icons.check_circle : Icons.check),
                      label: Text(_challengeDone ? "완료됨" : "도전 완료"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 칼로리 요약
            _MiniStatCard(
              title: "칼로리 요약",
              leading: Icons.local_fire_department,
              background: Colors.orange[50],
              primary: (_tdee == null) ? "프로필 필요" : "TDEE ${_tdee!.round()} kcal",
              secondary: (_tdee == null)
                  ? "성별·키·몸무게·나이·활동량을 프로필에 입력해 주세요."
                  : "오늘 섭취: ${(_todayCalories ?? 0).round()} kcal",
              badge: (_tdee != null && _todayCalories != null)
                  ? (kcalDelta! >= 0 ? "부족 ${kcalDelta} kcal" : "초과 ${kcalDelta.abs()} kcal")
                  : null,
              badgeColor: (kcalDelta != null && kcalDelta < 0) ? Colors.red[300] : Colors.green[300],
            ),
          ],
        ),
      ),
    );
  }
}

// 미니 카드 위젯
class _MiniStatCard extends StatelessWidget {
  final String title;
  final String primary;
  final String secondary;
  final String? badge;
  final IconData leading;
  final Color? background;
  final Color? badgeColor;

  const _MiniStatCard({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.leading,
    this.badge,
    this.background,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: background,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(leading, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor ?? Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        softWrap: false,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(primary, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(secondary, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
