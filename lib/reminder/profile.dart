import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 활동 수준
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityLevelX on ActivityLevel {
  double get factor => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };

  String get labelKo => switch (this) {
    ActivityLevel.sedentary => '좌식',
    ActivityLevel.light => '가벼움',
    ActivityLevel.moderate => '보통',
    ActivityLevel.active => '높음',
    ActivityLevel.veryActive => '매우 높음',
  };

  static ActivityLevel fromString(String s) => switch (s) {
    'light' => ActivityLevel.light,
    'moderate' => ActivityLevel.moderate,
    'active' => ActivityLevel.active,
    'very_active' => ActivityLevel.veryActive,
    _ => ActivityLevel.sedentary,
  };

  String get toFirestoreString => switch (this) {
    ActivityLevel.sedentary => 'sedentary',
    ActivityLevel.light => 'light',
    ActivityLevel.moderate => 'moderate',
    ActivityLevel.active => 'active',
    ActivityLevel.veryActive => 'very_active',
  };
}

// 성별(기본값 없음)
enum Sex { male, female }
extension SexX on Sex {
  String get labelKo => this == Sex.male ? '남성' : '여성';
  static Sex fromString(String s) => s == 'male' ? Sex.male : Sex.female;
  String get toFirestoreString => this == Sex.male ? 'male' : 'female';
}

class UserProfile {
  final int age;              // 세
  final double heightCm;      // cm
  final double weightKg;      // kg
  final ActivityLevel activityLevel;
  final Sex sex;

  const UserProfile({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.sex,
  });

  Map<String, dynamic> toMap() => {
    'age': age,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'activity_level': activityLevel.toFirestoreString,
    'sex': sex.toFirestoreString,
    'updated_at': FieldValue.serverTimestamp(),
  };

  // Firestore 문서 파싱(필수값 없으면 편집 시트 유도)
  static UserProfile? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;

    final age = d['age'];
    final height = d['height_cm'];
    final weight = d['weight_kg'];
    final act = d['activity_level'];
    final sex = d['sex'];
    if (age is! num || height is! num || weight is! num) return null;
    if (age <= 0 || height <= 0 || weight <= 0) return null;
    if (act is! String || sex is! String) return null;

    return UserProfile(
      age: age.toInt(),
      heightCm: (height as num).toDouble(),
      weightKg: (weight as num).toDouble(),
      activityLevel: ActivityLevelX.fromString(act),
      sex: SexX.fromString(sex),
    );
  }

  double get bmi {
    final m = heightCm / 100.0;
    return weightKg / (m * m);
  }

  double get bmr {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == Sex.male ? base + 5 : base - 161;
  }

  double get tdee => bmr * activityLevel.factor;
}

// Firestore 경로 헬퍼 (users/{uid}/profile/main)
DocumentReference<Map<String, dynamic>> profileRef(
    FirebaseFirestore db,
    String uid,
    ) =>
    db.collection('users').doc(uid).collection('profile').doc('main');

// 프로필 저장/로드/캐시 저장소
class ProfileRepository {
  final FirebaseFirestore db;
  ProfileRepository(this.db);

  Future<UserProfile?> fetchFromFirestore(String uid) async {
    final snap = await profileRef(db, uid).get();
    return UserProfile.fromDoc(snap);
  }

  Future<void> saveToFirestore(String uid, UserProfile p) async {
    await profileRef(db, uid).set(p.toMap(), SetOptions(merge: true));
  }

  Future<void> cacheLocal(UserProfile p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('profile_age', p.age);
    await sp.setDouble('profile_height_cm', p.heightCm);
    await sp.setDouble('profile_weight_kg', p.weightKg);
    await sp.setString('profile_activity_level', p.activityLevel.toFirestoreString);
    await sp.setString('profile_sex', p.sex.toFirestoreString);
  }

  Future<UserProfile?> loadCached() async {
    final sp = await SharedPreferences.getInstance();
    final age = sp.getInt('profile_age');
    final h = sp.getDouble('profile_height_cm');
    final w = sp.getDouble('profile_weight_kg');
    final act = sp.getString('profile_activity_level');
    final sex = sp.getString('profile_sex');
    if (age == null || h == null || w == null || act == null || sex == null) {
      return null;
    }
    if (age <= 0 || h <= 0 || w <= 0) return null;
    return UserProfile(
      age: age,
      heightCm: h,
      weightKg: w,
      activityLevel: ActivityLevelX.fromString(act),
      sex: SexX.fromString(sex),
    );
  }
}

// 프로필 편집 바텀시트 (기존값 보이도록)
class ProfileEditorSheet extends StatefulWidget {
  final UserProfile? initial;
  const ProfileEditorSheet({super.key, this.initial});

  @override
  State<ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ageC = TextEditingController();
  final _heightC = TextEditingController();
  final _weightC = TextEditingController();
  ActivityLevel _activity = ActivityLevel.sedentary;
  Sex? _sex; // 필수 선택

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      _ageC.text = p.age.toString();
      _heightC.text = p.heightCm.toStringAsFixed(1);
      _weightC.text = p.weightKg.toStringAsFixed(1);
      _activity = p.activityLevel;
      _sex = p.sex;
    }
  }

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
    if (_sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해 주세요.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final p = UserProfile(
      age: int.parse(_ageC.text),
      heightCm: double.parse(_heightC.text),
      weightKg: double.parse(_weightC.text),
      activityLevel: _activity,
      sex: _sex!, // 필수
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
            const Text('내 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            // 성별
            Row(
              children: [
                const Text('성별', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('남성'),
                        selected: _sex == Sex.male,
                        onSelected: (_) => setState(() => _sex = Sex.male),
                      ),
                      ChoiceChip(
                        label: const Text('여성'),
                        selected: _sex == Sex.female,
                        onSelected: (_) => setState(() => _sex = Sex.female),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            DropdownButtonFormField<ActivityLevel>(
              value: _activity,
              decoration: const InputDecoration(labelText: '활동 수준'),
              items: ActivityLevel.values
                  .map((lv) => DropdownMenuItem(value: lv, child: Text(lv.labelKo)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v ?? ActivityLevel.sedentary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _submit, child: const Text('저장')),
            ),
          ],
        ),
      ),
    );
  }
}
