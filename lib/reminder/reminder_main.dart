import 'package:flutter/material.dart';
import 'package:first_flutter_yjpark/reminder/home_screen.dart';
import 'package:first_flutter_yjpark/reminder/water_page.dart';
import 'calendar_page.dart';

// ▼ 추가된 import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first_flutter_yjpark/reminder/profile.dart';

class MainHomeScreen extends StatefulWidget {
  final String userName;
  const MainHomeScreen({super.key, required this.userName});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  // ▼ 프로필 상태
  UserProfile? _profile;
  bool _loadingProfile = true;

  // ▼ Firebase 핸들러
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _ensureProfile(); // 시작 시 프로필 확보
  }

  // ===== Firestore 경로 =====
  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _db.collection('users').doc(uid).collection('profile').doc('main');

  // ===== 프로필 로드/저장 =====
  Future<void> _ensureProfile() async {
    try {
      // 1) Firestore에서 로드
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final snap = await _profileRef(uid).get();
        final fromFs = UserProfile.fromDoc(snap);
        if (fromFs != null) {
          _profile = fromFs;
          await _cacheProfile(fromFs);
          setState(() => _loadingProfile = false);
          return;
        }
      }

      // 2) 로컬 캐시에서 로드
      final cached = await _loadCachedProfile();
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
    } catch (e) {
      // 오류가 있어도 앱이 진행되도록: 입력 시트 띄움
      setState(() => _loadingProfile = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openProfileSheet());
    }
  }

  Future<void> _saveProfile(UserProfile p) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _profileRef(uid).set(p.toMap(), SetOptions(merge: true));
    }
    await _cacheProfile(p);
    setState(() => _profile = p);
  }

  Future<void> _cacheProfile(UserProfile p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('profile_age', p.age);
    await sp.setDouble('profile_height_cm', p.heightCm);
    await sp.setDouble('profile_weight_kg', p.weightKg);
  }

  Future<UserProfile?> _loadCachedProfile() async {
    final sp = await SharedPreferences.getInstance();
    final age = sp.getInt('profile_age') ?? 0;
    final h = sp.getDouble('profile_height_cm') ?? 0;
    final w = sp.getDouble('profile_weight_kg') ?? 0;
    if (age > 0 && h > 0 && w > 0) {
      return UserProfile(age: age, heightCm: h, weightKg: w);
    }
    return null;
  }

  Future<void> _openProfileSheet() async {
    final result = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProfileSheet(),
    );
    if (result != null) {
      await _saveProfile(result);
      // 프로필 저장 이후 홈/요약 등에서 사용 가능
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장되었어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 기존 탭들
    final List<Widget> _widgetOptions = <Widget>[
      HomeScreen(userName: widget.userName),
      const WaterPage(),
      const CalendarPage(),
    ];

    // 프로필 로딩 중엔 로딩 화면
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // AppBar 제거!
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
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          _widgetOptions[_selectedIndex],

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
                tooltip: _profile == null
                    ? '내 정보 입력'
                    : '내 정보 수정 (${_profile!.age}세, ${_profile!.heightCm.toStringAsFixed(1)}cm, ${_profile!.weightKg.toStringAsFixed(1)}kg)',
                icon: const Icon(Icons.person),
                onPressed: _openProfileSheet,
              ),
            ),

          // (선택) 홈 화면일 때 현재 프로필 요약을 살짝 표시하고 싶다면:
          // if (_selectedIndex == 0 && _profile != null)
          //   Positioned(
          //     bottom: 12,
          //     left: 12,
          //     child: Chip(
          //       label: Text(
          //         '${_profile!.age}세 · ${_profile!.heightCm.toStringAsFixed(0)}cm · ${_profile!.weightKg.toStringAsFixed(1)}kg',
          //       ),
          //     ),
          //   ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Water'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
      ),
    );
  }
}

// ===== 프로필 입력 바텀시트 =====
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ageC = TextEditingController();
  final _heightC = TextEditingController();
  final _weightC = TextEditingController();

  @override
  void dispose() {
    _ageC.dispose();
    _heightC.dispose();
    _weightC.dispose();
    super.dispose();
  }

  String? _vInt(String? v, {int min = 5, int max = 100}) {
    if (v == null || v.trim().isEmpty) return '필수 입력';
    final n = int.tryParse(v);
    if (n == null) return '숫자로 입력하세요';
    if (n < min || n > max) return '$min~$max 사이로 입력';
    return null;
  }

  String? _vDouble(String? v, {double min = 30, double max = 300}) {
    if (v == null || v.trim().isEmpty) return '필수 입력';
    final n = double.tryParse(v);
    if (n == null) return '숫자로 입력하세요';
    if (n < min || n > max) return '$min~$max 사이로 입력';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final p = UserProfile(
      age: int.parse(_ageC.text),
      heightCm: double.parse(_heightC.text),
      weightKg: double.parse(_weightC.text),
    );
    Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Wrap(
          runSpacing: 12,
          children: [
            const Text('내 정보 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            TextFormField(
              controller: _ageC,
              decoration: const InputDecoration(labelText: '나이(세)'),
              keyboardType: TextInputType.number,
              validator: _vInt,
            ),
            TextFormField(
              controller: _heightC,
              decoration: const InputDecoration(labelText: '키(cm)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _vDouble(v, min: 50, max: 230),
            ),
            TextFormField(
              controller: _weightC,
              decoration: const InputDecoration(labelText: '몸무게(kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _vDouble(v, min: 20, max: 250),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
