package com.example.first_flutter_yjpark.alarm

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.example.first_flutter_yjpark.MainActivity
import com.example.first_flutter_yjpark.R

object NotificationHelper {
    private const val CHANNEL_ID = "medicine_reminders"
    private const val REQ_POST_NOTIF = 1001

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "약 복용 알림",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "약 복용 시간 알림"
                enableVibration(true)
                setShowBadge(true)
            }
            mgr.createNotificationChannel(ch)
        }
    }

    fun buildNotification(context: Context, title: String, text: String, nid: Int): Notification {
        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context, nid, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher) // 필요 시 전용 아이콘으로 교체
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
    }

    /** 단순 요청: 다이얼로그만 띄우고 콜백은 true로 반환(데모용). */
    fun requestPostNotificationPermission(
        activity: Activity,
        callback: (Boolean) -> Unit
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback(true); return
        }
        val granted = ActivityCompat.checkSelfPermission(
            activity, android.Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            callback(true)
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQ_POST_NOTIF
            )
            // 결과는 따로 받지 않고 true로 처리 (간단 테스트용)
            callback(true)
        }
    }
}
