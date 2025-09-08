import 'dart:io';
import 'package:flutter/services.dart';

class NativeAlarm {
  static const _ch = MethodChannel('com.yourapp.medicine/alarm');

  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final ok = await _ch.invokeMethod<bool>('requestNotificationPermission');
    return ok ?? true;
  }

  /// daysOfWeek: ISO 1=Mon ... 7=Sun, 빈 리스트면 매일
  static Future<void> scheduleAlarm({
    required int id,
    required int hour,
    required int minute,
    String label = '약 복용',
    List<int> daysOfWeek = const [],
  }) async {
    await _ch.invokeMethod('scheduleAlarm', {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
      'daysOfWeek': daysOfWeek,
    });
  }

  static Future<void> cancelAlarm(int id) async {
    await _ch.invokeMethod('cancelAlarm', {'id': id});
  }

  static Future<List<Map>> listAlarms() async {
    final res = await _ch.invokeMethod<List>('listAlarms');
    return (res ?? []).cast<Map>();
  }
}
