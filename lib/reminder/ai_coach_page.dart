import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart';

class AICoachPage extends StatefulWidget {
  const AICoachPage({super.key});

  @override
  State<AICoachPage> createState() => _AICoachPageState();
}

class _AICoachPageState extends State<AICoachPage> {
  String _dailyMessage = "불러오는 중...";
  String _dailyChallenge = "불러오는 중...";
  String _weeklyReport = "불러오는 중...";
  bool _challengeDone = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadAIContents();
  }

  Future<void> _loadAIContents() async {
    await Future.wait([
      _fetchDailyMessage(),
      _fetchDailyChallenge(),
      _fetchWeeklyReport(),
    ]);
  }

  // ===== Node.js 서버 호출 =====
  Future<String> _callAICoach(String type, {dynamic data, String? userName}) async {
    final response = await http.post(
      Uri.parse("$serverUrl/ai-coach"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "type": type,
        "data": data,
        "userName": userName,
      }),
    );

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      return res["message"] ?? "AI 응답 없음";
    } else {
      return "AI 서버 호출 실패 (${response.statusCode})";
    }
  }

  // ===== Firestore 캐싱 헬퍼 =====
  Future<String> _getDailyCached(String field, String type) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return "로그인 필요";

    final todayKey = DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd
    final docRef = _db.collection('users').doc(uid).collection('ai_coach').doc(todayKey);

    final snap = await docRef.get();
    if (snap.exists && snap.data()?[field] != null) {
      return snap.data()![field];
    }

    // 없으면 GPT 호출 → Firestore에 저장
    final result = await _callAICoach(type, userName: uid);
    await docRef.set({
      field: result,
      "createdAt": DateTime.now(),
    }, SetOptions(merge: true));

    return result;
  }

  // ===== 오늘의 활력 메시지 =====
  Future<void> _fetchDailyMessage() async {
    final msg = await _getDailyCached("dailyMessage", "dailyMessage");
    setState(() => _dailyMessage = msg);
  }

  // ===== 데일리 챌린지 =====
  Future<void> _fetchDailyChallenge() async {
    final challenge = await _getDailyCached("dailyChallenge", "dailyChallenge");
    setState(() => _dailyChallenge = challenge);
  }

  // ===== 주간 리포트 ===== (이건 매번 새로 호출)
  Future<void> _fetchWeeklyReport() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        setState(() => _weeklyReport = "로그인 필요");
        return;
      }

      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));

      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('water_intake')
          .where('date', isGreaterThan: lastWeek.toIso8601String())
          .get();

      if (snap.docs.isEmpty) {
        setState(() => _weeklyReport = "지난 7일 기록이 없어요 😢");
        return;
      }

      final data = snap.docs.map((d) => d['amount'] ?? 0).toList();
      final report = await _callAICoach("weeklyReport", data: data, userName: uid);
      setState(() => _weeklyReport = report);
    } catch (e) {
      setState(() => _weeklyReport = "리포트를 불러오는 중 오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text("오늘의 활력 메시지 💬",
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
                    const Text("오늘의 챌린지 🎯",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_dailyChallenge, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _challengeDone = !_challengeDone);
                      },
                      icon: Icon(_challengeDone ? Icons.check_circle : Icons.check),
                      label: Text(_challengeDone ? "완료됨" : "도전 완료"),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 주간 리포트
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("주간 리포트 📊",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_weeklyReport, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
