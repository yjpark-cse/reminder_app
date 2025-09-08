package com.example.first_flutter_yjpark.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        if (id == -1) return

        val item = AlarmStore.load(context).find { it.id == id } ?: return

        NotificationHelper.ensureChannel(context)
        val notif = NotificationHelper.buildNotification(
            context,
            "약 복용 시간",
            "${item.label} - 지금 복용할 시간이에요!",
            id
        )
        NotificationManagerCompat.from(context).notify(id, notif)

        // 다음 회차 자동 재예약
        AlarmScheduler.schedule(context, item.id, item.hour, item.minute, item.label, item.daysOfWeek)
    }
}
