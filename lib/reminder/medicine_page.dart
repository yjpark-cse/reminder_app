import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../notification_service.dart';
import 'medicine_register_page.dart';

class MedicinePage extends StatefulWidget {
  const MedicinePage({super.key});

  @override
  State<MedicinePage> createState() => _MedicinePageState();
}

class _MedicinePageState extends State<MedicinePage> {
  Future<void> _toggleTaken(String docId, String timeKey, bool currentValue) async {
    final now = DateTime.now();
    final todayKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    await FirebaseFirestore.instance.collection('medicines').doc(docId).set({
      'taken': {
        todayKey: {
          timeKey: !currentValue,
        }
      }
    }, SetOptions(merge: true));

    setState(() {});
  }

  Future<void> _deleteWithCancel(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString();

    try {
      // 1) OS에 예약된 알림부터 전부 취소 (payload == name)
      await cancelMedicineNotificationsById(name);
    } catch (e) {
      // 실패해도 Firestore 삭제는 계속
    }

    // 2) Firestore 문서 삭제
    await FirebaseFirestore.instance.collection('medicines').doc(doc.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("약 복용 확인")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medicines')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("등록된 약이 없습니다."));
          }

          final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final taken = (data['taken'] ?? {})[todayKey] ?? {};

              return Card(
                margin: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            (data['name'] ?? '').toString(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ...List<Widget>.from((data['times'] as List).map((t) {
                            return Row(
                              children: [
                                Text("🕒 $t"),
                                const Spacer(),
                                Checkbox(
                                  value: taken[t] ?? false,
                                  onChanged: (_) => _toggleTaken(doc.id, t, taken[t] ?? false),
                                ),
                              ],
                            );
                          })),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _deleteWithCancel(doc), // ✅ 변경: 취소 + 삭제
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicineRegisterPage()));
        },
      ),
    );
  }
}
