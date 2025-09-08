package com.example.first_flutter_yjpark

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.first_flutter_yjpark.alarm.AlarmScheduler
import com.example.first_flutter_yjpark.alarm.NotificationHelper

class MainActivity : FlutterActivity() {

    private val channelName = "com.yourapp.medicine/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        NotificationHelper.requestPostNotificationPermission(this) { granted ->
                            result.success(granted)
                        }
                    }
                    "scheduleAlarm" -> {
                        val id = call.argument<Int>("id")!!
                        val hour = call.argument<Int>("hour")!!
                        val minute = call.argument<Int>("minute")!!
                        val label = call.argument<String>("label") ?: "약 복용"
                        val days = call.argument<List<Int>>("daysOfWeek") ?: emptyList()
                        AlarmScheduler.schedule(this, id, hour, minute, label, days)
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        val id = call.argument<Int>("id")!!
                        AlarmScheduler.cancel(this, id)
                        result.success(true)
                    }
                    "listAlarms" -> {
                        result.success(AlarmScheduler.list(this))
                    }
                    "cancelByMedicine" -> {
                        val medicineId = call.argument<Int>("medicineId")!!
                        AlarmScheduler.cancelByMedicineId(this, medicineId)
                        result.success(true)
                    }
                    "rescheduleAll" -> {
                        AlarmScheduler.rescheduleAll(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
