import 'package:flutter/material.dart';

class MedicinePage extends StatelessWidget {
  const MedicinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("약 복용")),
      body: Center(child: Text("준비중")),
    );
  }
}
