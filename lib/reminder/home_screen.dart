import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first_flutter_yjpark/reminder/diet_page.dart';
import 'package:first_flutter_yjpark/reminder/medicine_page.dart';
import 'package:first_flutter_yjpark/reminder/water_page.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _waterCups = 0;
  int _dietCount = 0;
  bool _medicineTaken = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterCups = prefs.getInt('today_water') ?? 0;
      _dietCount = prefs.getInt('today_diet') ?? 0;
      _medicineTaken = prefs.getBool('medicine_taken') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200], // 배경을 밝은 회색으로 설정
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            _buildCard(
              context,
              title: '오늘의 식단 기록',
              icon: Icons.restaurant_menu,
              iconColor: Colors.orange[200]!,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DietPage()),
                );
                _loadData();
              },
            ),
            _buildCard(
              context,
              title: '약 복용 관리',
              icon: Icons.medical_services,
              iconColor: Colors.lightGreen[200]!,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicinePage()),
                );
                _loadData();
              },
            ),
            _buildCard(
              context,
              title: '물 마시기',
              icon: Icons.water_drop,
              iconColor: Colors.blue[200]!,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WaterPage()),
                );
                _loadData();
              },
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color iconColor,
        required VoidCallback onTap,
        double? progress,
      }) {
    return Card(
      color: Colors.white, // 카드 배경을 하얗게 설정
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, size: 30, color: Colors.black87),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        color: Colors.blue,
                      )
                    ]
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
