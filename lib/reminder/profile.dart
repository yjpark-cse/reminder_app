import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final int age;           // 나이
  final double heightCm;   // cm
  final double weightKg;   // kg

  const UserProfile({
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  Map<String, dynamic> toMap() => {
    'age': age,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'updated_at': FieldValue.serverTimestamp(),
  };

  static UserProfile? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    final age = (d['age'] ?? 0);
    final height = (d['height_cm'] ?? 0);
    final weight = (d['weight_kg'] ?? 0);
    if (age is! num || height is! num || weight is! num) return null;
    if (age <= 0 || height <= 0 || weight <= 0) return null;
    return UserProfile(
      age: age.toInt(),
      heightCm: (height as num).toDouble(),
      weightKg: (weight as num).toDouble(),
    );
  }
}
