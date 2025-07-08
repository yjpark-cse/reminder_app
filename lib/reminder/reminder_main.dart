import 'package:flutter/material.dart';
import 'package:first_flutter_yjpark/reminder/home_screen.dart';
import 'package:first_flutter_yjpark/reminder/water_page.dart';
import 'calendar_page.dart';

class MainHomeScreen extends StatefulWidget {
  final String userName;
  const MainHomeScreen({super.key, required this.userName});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _widgetOptions = <Widget>[
      HomeScreen(userName: widget.userName),
      WaterPage(),
      CalendarPage(),
    ];

    return Scaffold(
      // AppBar 제거!
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text('${widget.userName}님 환영합니다!',
                  style: const TextStyle(color: Colors.white, fontSize: 24)),
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
          if (_selectedIndex == 0) // 홈 화면일 때만 드로어 버튼 표시
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
