package com.example.first_flutter_yjpark.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                NotificationHelper.ensureChannel(context)
                AlarmScheduler.rescheduleAll(context)
            }
        }
    }
}
