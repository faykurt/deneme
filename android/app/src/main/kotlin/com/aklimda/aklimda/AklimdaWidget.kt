package com.aklimda.aklimda

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Ana ekran widget'ı: sesli not ve yazılı not butonları uygulamayı ilgili ekranda açar. */
class AklimdaWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.aklimda_widget).apply {
                setOnClickPendingIntent(
                    R.id.sesli_not,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("aklimda://sesli")),
                )
                setOnClickPendingIntent(
                    R.id.yazili_not,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("aklimda://yazili")),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
