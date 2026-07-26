package com.oneb.anikin

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AnikinHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.anikin_home_widget).apply {
                setOnClickPendingIntent(
                    R.id.widget_container,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setTextViewText(
                    R.id.widget_continue_title,
                    widgetData.getString("continue_title", "Nothing in progress"),
                )
                setTextViewText(
                    R.id.widget_continue_subtitle,
                    widgetData.getString("continue_subtitle", "Open Anikin to start watching"),
                )
                setProgressBar(
                    R.id.widget_progress,
                    100,
                    widgetData.getInt("continue_progress", 0).coerceIn(0, 100),
                    false,
                )
                setTextViewText(
                    R.id.widget_next_title,
                    widgetData.getString("next_title", "No upcoming release synced"),
                )
                setTextViewText(
                    R.id.widget_next_time,
                    widgetData.getString("next_time", "Enable release alerts in Anikin"),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
