import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';

import 'firebase_options.dart';
import 'reminder/login_signup.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart'; // 🔔 권한 요청 패키지

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await requestNotificationPermission(); // 알림 권한 요청 추가
  await initNotification();              // 알림 초기화

  await HomeWidget.registerBackgroundCallback(backgroundCallback);

  runApp(MyApp());
}

// 알림 권한 요청 함수 (Android 13+ 대응)
Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

// 알림 초기화 함수
Future<void> initNotification() async {
  tz.initializeTimeZones();
  final seoul = await tz.getLocation('Asia/Seoul');
  tz.setLocalLocation(seoul);

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// 홈 위젯 백그라운드 콜백
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'updatecounter') {
    int _counter = 0;
    await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0)
        .then((int? value) {
      _counter = value ?? 0;
      _counter++;
    });
    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.updateWidget(name: 'WidgetProvider');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '식단관리 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWidget(),
    );
  }
}
