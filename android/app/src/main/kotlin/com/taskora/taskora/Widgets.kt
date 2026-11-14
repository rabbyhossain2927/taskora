package com.taskora.taskora

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

// Home screen widgets. The app writes the data (and two pictures) whenever it
// syncs; tapping a widget opens TaskOra with a link that says what to do.

private fun open(context: Context, link: String) =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

private fun showImage(context: Context, views: RemoteViews, data: SharedPreferences, key: String) {
    val path = data.getString(key, null)
    val file = if (path == null) null else File(path)
    if (file != null && file.exists()) {
        val bmp = BitmapFactory.decodeFile(file.absolutePath)
        if (bmp != null) {
            views.setImageViewBitmap(R.id.image, bmp)
            views.setViewVisibility(R.id.empty, View.GONE)
            return
        }
    }
    views.setViewVisibility(R.id.empty, View.VISIBLE)
}

class TodayRingWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_image)
            showImage(context, v, widgetData, "ring_img")
            v.setOnClickPendingIntent(R.id.root, open(context, "taskora://todos"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

class DashboardWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_image)
            showImage(context, v, widgetData, "dash_img")
            v.setOnClickPendingIntent(R.id.root, open(context, "taskora://home"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

class TodosWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val rows = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3)
        val titles = intArrayOf(R.id.title0, R.id.title1, R.id.title2, R.id.title3)
        val whens = intArrayOf(R.id.when0, R.id.when1, R.id.when2, R.id.when3)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_todos)
            v.setTextViewText(R.id.count, widgetData.getString("today_count", "") ?: "")
            var shown = 0
            for (i in 0..3) {
                val t = widgetData.getString("todo${i}_title", null)
                if (t.isNullOrEmpty()) {
                    v.setViewVisibility(rows[i], View.GONE)
                } else {
                    shown++
                    v.setViewVisibility(rows[i], View.VISIBLE)
                    v.setTextViewText(titles[i], t)
                    val w = widgetData.getString("todo${i}_when", "") ?: ""
                    v.setTextViewText(whens[i], w)
                    v.setTextColor(whens[i], if (w == "Overdue") 0xFFD83A3A.toInt() else 0xFF7A7A8C.toInt())
                    val tid = widgetData.getString("todo${i}_id", "") ?: ""
                    v.setOnClickPendingIntent(rows[i], open(context, "taskora://todo/done?id=$tid"))
                }
            }
            v.setViewVisibility(R.id.none, if (shown == 0) View.VISIBLE else View.GONE)
            v.setOnClickPendingIntent(R.id.add, open(context, "taskora://add/todo"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

class FocusWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_focus)
            val endsAt = widgetData.getString("focus_end", "0")?.toLongOrNull() ?: 0L // wall-clock ms when the running session ends
            val left = endsAt - System.currentTimeMillis()
            val running = endsAt > 0 && left > 0
            v.setTextViewText(R.id.state, widgetData.getString("focus_state", "Ready when you are") ?: "")
            if (running && Build.VERSION.SDK_INT >= 24) {
                v.setViewVisibility(R.id.time, View.GONE)
                v.setViewVisibility(R.id.chrono, View.VISIBLE)
                v.setChronometer(R.id.chrono, SystemClock.elapsedRealtime() + left, null, true)
                v.setChronometerCountDown(R.id.chrono, true)
                v.setTextViewText(R.id.start, "Open")
            } else {
                v.setViewVisibility(R.id.chrono, View.GONE)
                v.setViewVisibility(R.id.time, View.VISIBLE)
                v.setTextViewText(R.id.time, widgetData.getString("focus_time", "25:00") ?: "25:00")
                v.setTextViewText(R.id.start, if (running) "Open" else "Start")
            }
            v.setOnClickPendingIntent(R.id.start, open(context, "taskora://focus"))
            v.setOnClickPendingIntent(R.id.root, open(context, "taskora://focus"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

class QuickAddWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_quickadd)
            v.setOnClickPendingIntent(R.id.qa_todo, open(context, "taskora://add/todo"))
            v.setOnClickPendingIntent(R.id.qa_note, open(context, "taskora://add/note"))
            v.setOnClickPendingIntent(R.id.qa_project, open(context, "taskora://add/project"))
            v.setOnClickPendingIntent(R.id.qa_focus, open(context, "taskora://focus"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

class PinnedNoteWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_note)
            v.setTextViewText(R.id.title, widgetData.getString("note_title", "No pinned note") ?: "")
            v.setTextViewText(R.id.body, widgetData.getString("note_body", "Pin a note in TaskOra to see it here.") ?: "")
            val nid = widgetData.getString("note_id", "") ?: ""
            v.setOnClickPendingIntent(R.id.root, open(context, if (nid.isEmpty()) "taskora://notes" else "taskora://note?id=$nid"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

class StreakWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_streak)
            v.setTextViewText(R.id.days, widgetData.getString("streak", "0") ?: "0")
            v.setOnClickPendingIntent(R.id.root, open(context, "taskora://home"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
