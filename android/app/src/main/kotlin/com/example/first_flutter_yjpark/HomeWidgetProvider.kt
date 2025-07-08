// ✅ Kotlin 코드 전체 (HomeWidgetProvider.kt)

package com.example.first_flutter_yjpark

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val count = widgetData.getInt("water_count", 0)
            val views = RemoteViews(context.packageName, R.layout.home_widget).apply {
                setTextViewText(R.id.water_count, "물 마신 횟수: ${count}잔")

                val intent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("myAppWidget://drinkWater")
                )
                setOnClickPendingIntent(R.id.button_plus, intent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
