import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class NativeAlarmBridge {
  static const MethodChannel _ch = MethodChannel('com.yourapp.medicine/alarm');

  /// Android 13+ POST_NOTIFICATIONS 권한 요청
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('requestNotificationPermission');
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  /// 단일 알람 예약
  /// [daysOfWeek] : 1=Mon..7=Sun, 빈 리스트면 "매일"로 동작 (네이티브 로직 준수)
  static Future<bool> scheduleAlarm({
    required int id,
    required int hour,
    required int minute,
    required String label,
    List<int> daysOfWeek = const [],
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('scheduleAlarm', {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'daysOfWeek': daysOfWeek,
      });
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  /// 여러 건을 한 번에 예약하고 싶을 때
  static Future<bool> scheduleAlarmsBulk(List<Map<String, dynamic>> items) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('scheduleAlarms', items);
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  /// 알람 1건 취소 (id 기준)
  static Future<bool> cancelAlarm(int id) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('cancelAlarm', {'id': id});
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  /// 특정 약(medicineId)의 모든 슬롯 알람 취소
  /// (규칙: alarmId = medicineId*100 + slot)
  static Future<bool> cancelByMedicine(int medicineId) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('cancelByMedicine', {'medicineId': medicineId});
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  /// 네이티브 저장소(AlarmStore)에 있는 모든 항목 재등록
  static Future<bool> rescheduleAll() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('rescheduleAll');
      return ok == true;
    } on PlatformException {
      return false;
    }
  }

  /// 현재 네이티브에 저장된 알람 목록 조회
  /// 반환 예:
  /// [{'id':12300,'hour':8,'minute':0,'label':'비타민D','daysOfWeek':[1,2,3,4,5,6,7]}, ...]
  static Future<List<Map<String, dynamic>>> listAlarms() async {
    if (!Platform.isAndroid) return const [];
    try {
      final r = await _ch.invokeMethod('listAlarms');
      final list = (r as List?) ?? const [];
      return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PlatformException {
      return const [];
    }
  }

  /// alarmId = medicineId*100 + slot (공유 규칙)
  static int buildAlarmId({required int medicineId, required int slot}) =>
      medicineId * 100 + slot;

  /// slot 단위 예약 헬퍼 (라벨/요일 그대로 전달)
  static Future<bool> scheduleMedicineSlot({
    required int medicineId,
    required int slot,
    required int hour,
    required int minute,
    required String label,
    List<int> daysOfWeek = const [],
  }) {
    return scheduleAlarm(
      id: buildAlarmId(medicineId: medicineId, slot: slot),
      hour: hour,
      minute: minute,
      label: label,
      daysOfWeek: daysOfWeek,
    );
  }

  /// slot 단위 취소 헬퍼
  static Future<bool> cancelMedicineSlot({
    required int medicineId,
    required int slot,
  }) {
    return cancelAlarm(buildAlarmId(medicineId: medicineId, slot: slot));
  }
}
