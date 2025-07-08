import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  int _counter = 0;
  int _goal = 8; // 기본 목표: 8잔

  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => loadData());
    loadData();
  }

  void loadData() async {
    await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0)
        .then((int? value) => _counter = value ?? 0);

    final prefs = await SharedPreferences.getInstance();
    _goal = prefs.getInt('water_goal') ?? 8;

    setState(() {});
  }

  Future<void> updateAppWidget() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('_counter', _counter);

    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.updateWidget(name: 'WidgetProvider');

    // 오늘 날짜 (yyyy-MM-dd)
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Firestore에 저장
    await FirebaseFirestore.instance
        .collection('water_records')
        .doc(today)
        .set({
      'count': _counter,
      'goal': _goal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _incrementCounter() {
    setState(() => _counter++);
    updateAppWidget();
  }

  void _decrementCounter() {
    if (_counter > 0) {
      setState(() => _counter--);
      updateAppWidget();
    }
  }

  void _showGoalDialog() {
    final TextEditingController _goalController =
    TextEditingController(text: '$_goal');

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('하루 물 목표량 설정'),
            content: TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '목표 잔 수'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final input = int.tryParse(_goalController.text);
                  if (input != null && input > 0) {
                    setState(() {
                      _goal = input;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    prefs.setInt('water_goal', _goal);
                  }
                  Navigator.pop(context);
                },
                child: Text('저장'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_goal > 0) ? (_counter / _goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[200],
        title: Text(
          '오늘의 수분 섭취',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showGoalDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 메인 수분 섭취 내용
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('오늘 마신 물의 양',
                      style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 10),
                  Text(
                    '$_counter / $_goal 잔',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: Colors.blue[800]),
                  ),
                  SizedBox(height: 30),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20), // 테두리 둥글게
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[300],
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('${(progress * 100).toInt()}% 달성'),
                ],
              ),
            ),
          ),

          // 오른쪽 하단에 위(+), 아래(-) 버튼
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
                    child: Icon(Icons.water_drop),
                  ),
                  SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'decrease',
                    backgroundColor: Colors.yellow[300],
                    onPressed: _decrementCounter,
                    tooltip: '물 한 잔 감소',
                    child: Icon(Icons.water_drop_outlined),
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
