package com.example.first_flutter_yjpark

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.example.first_flutter_yjpark.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

// 라이브러리의 HomeWidgetProvider를 FQCN으로 지정해 충돌/오인 방지
class WidgetProvider : es.antonborri.home_widget.HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // 위젯 전체를 누르면 앱 열기
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val counter = widgetData.getInt("_counter", 0)
                val counterText =
                    if (counter == 0) "아직 물을 마시지 않았어요" else "오늘 마신 물: $counter 잔"
                setTextViewText(R.id.tv_counter, counterText)

                // + 버튼 Flutter 백그라운드 콜백 호출
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("myAppWidget://updatecounter")
                )
                setOnClickPendingIntent(R.id.bt_update, backgroundIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
