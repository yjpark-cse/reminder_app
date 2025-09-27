import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'ai_coach_page.dart';
import 'calendar_page.dart';
import 'login_signup.dart';
import 'profile.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainHomeScreen extends StatefulWidget {
  final String userName;
  const MainHomeScreen({super.key, required this.userName});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  //프로필 상태
  UserProfile? _profile;
  bool _loadingProfile = true;

  //Firebase Repo
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late final ProfileRepository _repo = ProfileRepository(_db);

  @override
  void initState() {
    super.initState();
    _ensureProfile(); // 시작 시 프로필 확보
  }

  //프로필 로드 순서: Firestore → 캐시 → 시트
  Future<void> _ensureProfile() async {
    try {
      final uid = _auth.currentUser?.uid;

      // 1) Firestore에서 로드
      if (uid != null) {
        final fromFs = await _repo.fetchFromFirestore(uid);
        if (fromFs != null) {
          _profile = fromFs;
          await _repo.cacheLocal(fromFs);
          setState(() => _loadingProfile = false);
          return;
        }
      }

      // 2) 로컬 캐시에서 로드
      final cached = await _repo.loadCached();
      if (cached != null) {
        setState(() {
          _profile = cached;
          _loadingProfile = false;
        });
        return;
      }

      // 3) 둘 다 없으면 입력 시트 오픈
      setState(() => _loadingProfile = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openProfileSheet());
    } catch (_) {
      // 오류가 있어도 앱 실행되도록 입력 시트 띄움
      setState(() => _loadingProfile = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openProfileSheet());
    }
  }

  // 프로필 편집/저장
  Future<void> _openProfileSheet() async {
    final result = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProfileEditorSheet(initial: _profile), // 기존값 프리필
    );

    if (result != null) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _repo.saveToFirestore(uid, result); // Firestore 저장
      }
      await _repo.cacheLocal(result); // 캐시 저장
      setState(() => _profile = result);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장되었어요.')),
      );
    }
  }

  //로그아웃
  Future<void> _logout() async {
    try {
      // 1) Firebase Auth 로그아웃
      await _auth.signOut();

      // 2) 로컬 캐시 정리 (계정 전환 시 이전 사용자 정보 잔상 방지)
      final sp = await SharedPreferences.getInstance();
      await sp.remove('profile_age');
      await sp.remove('profile_height_cm');
      await sp.remove('profile_weight_kg');
      await sp.remove('profile_activity_level');
      await sp.remove('profile_sex');

      // 3) 메모리 상태 초기화
      if (mounted) {
        setState(() => _profile = null);
      }

      // 4) 로그인 화면으로 이동 (백스택 제거)
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthWidget()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
      );
    }
  }

  String _profileTooltip(UserProfile? p) {
    if (p == null) return '내 정보 입력';
    final sex = p.sex == Sex.male ? '남' : '여';
    final act = p.activityLevel.labelKo;
    return '내 정보 수정 (${p.age}세, ${p.heightCm.toStringAsFixed(1)}cm, ${p.weightKg.toStringAsFixed(1)}kg, $sex, $act)';
  }

  @override
  Widget build(BuildContext context) {
    // 기존 탭들
    final List<Widget> pages = <Widget>[
      HomeScreen(userName: widget.userName),
      const AICoachPage(),
      const CalendarPage(),
    ];

    // 프로필 로딩 중엔 로딩 화면
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text(
                '${widget.userName}님 환영합니다!',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text('내 정보 수정'),
              onTap: () async {
                Navigator.pop(context);
                await _openProfileSheet();
              },
            ),
            ListTile(
              title: const Text('로그아웃'),
              onTap: () async {
                Navigator.pop(context);
                await _logout();
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          pages[_selectedIndex],

          // 홈 화면일 때만 좌측 상단 햄버거는 기존처럼 유지
          if (_selectedIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),

          // 홈 화면일 때만 우측 상단 "내 정보" 버튼(사람 아이콘) 추가
          if (_selectedIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                tooltip: _profileTooltip(_profile),
                icon: const Icon(Icons.person),
                onPressed: _openProfileSheet,
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI코치'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
      ),
    );
  }
}
