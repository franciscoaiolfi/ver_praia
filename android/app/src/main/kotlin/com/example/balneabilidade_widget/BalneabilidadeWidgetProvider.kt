package com.balneabilidade_widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.balneabilidade_widget.R

class BalneabilidadeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.balneabilidade_widget)
            views.setTextViewText(R.id.widget_title, "Atualizando...")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
