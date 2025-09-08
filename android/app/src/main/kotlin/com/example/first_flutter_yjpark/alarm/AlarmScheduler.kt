package com.example.first_flutter_yjpark.alarm

import android.app.AlarmManager
import android.app.AlarmManager.AlarmClockInfo
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar
import java.util.concurrent.TimeUnit
import kotlin.math.max

object AlarmScheduler {

    private fun firePi(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("id", id)
        }
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedule(context: Context, id: Int, hour: Int, minute: Int, label: String, daysOfWeek: List<Int>) {
        val item = AlarmItem(id, hour, minute, label, daysOfWeek)
        AlarmStore.upsert(context, item)

        val nextTime = computeNextTriggerMillis(hour, minute, daysOfWeek)
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // 알람시계 표시용 show intent (필수는 아니지만 UX 좋음)
        val showIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("fireNow", true)
        }
        val showPi = PendingIntent.getBroadcast(
            context, id shl 1, showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val info = AlarmClockInfo(nextTime, showPi)
        mgr.setAlarmClock(info, firePi(context, id))
    }

    fun cancel(context: Context, id: Int) {
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        mgr.cancel(firePi(context, id))
        AlarmStore.remove(context, id)
    }

    fun list(context: Context): List<Map<String, Any>> =
        AlarmStore.load(context).map {
            mapOf(
                "id" to it.id,
                "hour" to it.hour,
                "minute" to it.minute,
                "label" to it.label,
                "daysOfWeek" to it.daysOfWeek
            )
        }

    fun rescheduleAll(context: Context) {
        AlarmStore.load(context).forEach {
            schedule(context, it.id, it.hour, it.minute, it.label, it.daysOfWeek)
        }
    }

    private fun computeNextTriggerMillis(hour: Int, minute: Int, days: List<Int>): Long {
        val now = Calendar.getInstance()
        val cand = Calendar.getInstance().apply {
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
        }
        fun javaToIso(d: Int) = if (d == Calendar.SUNDAY) 7 else d - 1

        if (cand.timeInMillis <= now.timeInMillis) cand.add(Calendar.DAY_OF_YEAR, 1)

        if (days.isEmpty()) {
            // 매일
            if (cand.timeInMillis <= now.timeInMillis) cand.add(Calendar.DAY_OF_YEAR, 1)
        } else {
            var guard = 0
            while (true) {
                val iso = javaToIso(cand.get(Calendar.DAY_OF_WEEK))
                if (cand.timeInMillis > now.timeInMillis && days.contains(iso)) break
                cand.add(Calendar.DAY_OF_YEAR, 1)
                guard++; if (guard > 8) break
            }
        }
        return max(cand.timeInMillis, now.timeInMillis + TimeUnit.SECONDS.toMillis(1))
    }

    //특정 약의 모든 알람 취소
    fun cancelByMedicineId(context: Context, medicineId: Int) {
        val all = AlarmStore.load(context)
        val targets = all.filter { it.id / 100 == medicineId } //같은 약 그룹
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        targets.forEach { item ->
            mgr.cancel(
                PendingIntent.getBroadcast(
                    context, item.id,
                    Intent(context, AlarmReceiver::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        AlarmStore.removeMany(context, targets.map { it.id })
    }
}
