import 'package:flutter/material.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _newFoodNameController = TextEditingController();
  final TextEditingController _newFoodCalorieController = TextEditingController();

  String _result = '';

  // 간단한 음식 칼로리 테이블
  final Map<String, double> _calorieTable = {
    '밥': 130,   // 100g당 kcal
    '계란': 75,  // 1개당 kcal
    '닭가슴살': 165,
    '사과': 52,
  };

  void _calculateCalories() {
    String food = _foodController.text.trim();
    double? amount = double.tryParse(_amountController.text.trim());

    if (food.isEmpty || amount == null) {
      setState(() {
        _result = '음식명과 양을 정확히 입력해주세요.';
      });
      return;
    }

    double? calPerUnit = _calorieTable[food];
    if (calPerUnit == null) {
      setState(() {
        _result = '칼로리 정보가 없는 음식입니다.';
      });
      return;
    }

    double totalCal = calPerUnit * amount;
    setState(() {
      _result = '$food ${amount.toStringAsFixed(1)} 단위 = ${totalCal.toStringAsFixed(1)} kcal';
    });
  }

  void _addNewFood() {
    String newFood = _newFoodNameController.text.trim();
    double? newCalorie = double.tryParse(_newFoodCalorieController.text.trim());

    if (newFood.isEmpty || newCalorie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음식명과 칼로리를 올바르게 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _calorieTable[newFood] = newCalorie;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$newFood 이(가) 추가되었습니다.')),
    );

    _newFoodNameController.clear();
    _newFoodCalorieController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("오늘 식단")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('칼로리 계산기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _foodController,
                      decoration: const InputDecoration(labelText: '음식 이름 (예: 밥, 계란)'),
                    ),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '양 (100g 또는 개수)'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _calculateCalories,
                      child: const Text('칼로리 계산'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _result,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('음식 직접 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _newFoodNameController,
                      decoration: const InputDecoration(labelText: '새 음식 이름'),
                    ),
                    TextField(
                      controller: _newFoodCalorieController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '칼로리 (1단위당 kcal)'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _addNewFood,
                      child: const Text('음식 추가'),
                    ),
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
