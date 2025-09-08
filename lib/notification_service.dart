import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 전역 플러그인 (앱 전체 하나만)
final FlutterLocalNotificationsPlugin _noti = FlutterLocalNotificationsPlugin();

bool _initialized = false;

const String _channelId = 'medicine_channel';
const String _channelName = '약 복용 알림';
const String _channelDesc = '약 복용 시간을 알려주는 알림';

const NotificationDetails _details = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  ),
);

/// 앱 시작 시 1회
Future<void> NotificationService_init() async {
  if (_initialized) return;

  // 타임존 초기화 (한국 고정)
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

  // 플러그인 초기화
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await _noti.initialize(initSettings);

  // Android 13+ 권한 요청
  final android =
  _noti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final enabled = await android?.areNotificationsEnabled();
  if (enabled == false) {
    await android?.requestNotificationsPermission();
  }

  _initialized = true;
}

/// 즉시 알림(자가진단)
Future<void> NotificationService_showImmediateTest() async {
  await NotificationService_init();
  await _noti.show(9999, '테스트', '즉시 표시되는 알림입니다', _details);
}

/// 안정적인 정수 ID 생성
int _stableId(String s) {
  int h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

int _weekdayFromKo(String d) {
  switch (d) {
    case '월': return DateTime.monday;
    case '화': return DateTime.tuesday;
    case '수': return DateTime.wednesday;
    case '목': return DateTime.thursday;
    case '금': return DateTime.friday;
    case '토': return DateTime.saturday;
    case '일': return DateTime.sunday;
    default:   return DateTime.monday;
  }
}

tz.TZDateTime _nextDailyTime(int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (when.isBefore(now)) when = when.add(const Duration(days: 1));
  return when;
}

tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  while (when.weekday != weekday || when.isBefore(now)) {
    when = when.add(const Duration(days: 1));
  }
  return when;
}

/// 예약 (요일 미선택=1회성, 선택=반복)
Future<void> scheduleMedicineNotification({
  required String id,        // 약 이름 등 묶음 식별자
  required String title,
  required String body,
  required TimeOfDay time,
  required List<String> repeatDays,
}) async {
  await NotificationService_init();

  // 1) 1회성 (matchDateTimeComponents 주지 않음)
  if (repeatDays.isEmpty) {
    final when = _nextDailyTime(time.hour, time.minute);
    final notifId = _stableId('$id-once-${when.toIso8601String()}');
    await _noti.zonedSchedule(
      notifId,
      title,
      body,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: id, // ← 취소 시 payload로 매칭
    );
    return;
  }

  // 2) 요일 반복
  for (final d in repeatDays) {
    final weekday = _weekdayFromKo(d);
    final when = _nextWeekdayTime(weekday, time.hour, time.minute);
    final notifId = _stableId('$id-$weekday-${time.hour}:${time.minute}');
    await _noti.zonedSchedule(
      notifId,
      title,
      body,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: id, // ← 취소 시 payload로 매칭
    );
  }
}

/// 🔴 약 이름(id)으로 예약 전부 취소
/// - 예약 시 payload에 id를 넣어뒀기 때문에, pending에서 payload==id인 항목을 전부 취소
Future<void> cancelMedicineNotificationsById(String id) async {
  await NotificationService_init();
  final pending = await _noti.pendingNotificationRequests();
  for (final r in pending) {
    if ((r.payload ?? '') == id) {
      await _noti.cancel(r.id);
    }
  }
}

/// (옵션) 모두 취소
Future<void> NotificationService_cancelAll() async {
  await NotificationService_init();
  await _noti.cancelAll();
}

/// ✅ 현재 예약(펜딩) 목록 출력: Android Studio 콘솔에서 확인
Future<void> debugPrintPending() async {
  await NotificationService_init();
  final list = await _noti.pendingNotificationRequests();
  debugPrint('📋 Pending notifications = ${list.length}');
  for (final r in list) {
    debugPrint(' - id=${r.id}, title=${r.title}, payload=${r.payload}');
  }
}

/// ✅ 2분 뒤 1회성 테스트 알림 예약 (alarmClock 모드)
Future<void> debugOneShotIn120s_alarmClock() async {
  await NotificationService_init();
  final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));
  debugPrint('[alarmClock] NOW=${tz.TZDateTime.now(tz.local)} WHEN=$when');

  await _noti.zonedSchedule(
    810001, // 고정 테스트 ID
    '테스트(1회성-alarmClock)',
    '2분 뒤 울립니다',
    when,
    _details,
    androidScheduleMode: AndroidScheduleMode.alarmClock,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    payload: 'DEBUG_TEST', // 식별용
  );
}
