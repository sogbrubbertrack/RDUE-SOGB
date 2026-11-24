package com.example.rubberway

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

object FormationReminderScheduler {
    private const val PREFS = "rubberway_formation_reminders"
    private const val PREFIX = "reminder_"
    const val EXTRA_ID = "formation_id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"

    fun schedule(
        context: Context,
        id: Int,
        scheduledAt: Long,
        title: String,
        body: String,
        persist: Boolean = true,
    ) {
        val triggerAt = if (scheduledAt <= System.currentTimeMillis()) {
            System.currentTimeMillis() + 5_000L
        } else scheduledAt

        if (persist) {
            val saved = JSONObject()
                .put("id", id)
                .put("scheduledAt", triggerAt)
                .put("title", title)
                .put("body", body)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(PREFIX + id, saved.toString())
                .apply()
        }

        val intent = Intent(context, FormationReminderReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    fun cancel(context: Context, id: Int) {
        val intent = Intent(context, FormationReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pendingIntent)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(PREFIX + id)
            .apply()
    }

    fun rescheduleAfterRestart(context: Context) {
        val reminders = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).all
        for ((key, value) in reminders) {
            if (!key.startsWith(PREFIX) || value !is String) continue
            try {
                val reminder = JSONObject(value)
                schedule(
                    context = context,
                    id = reminder.getInt("id"),
                    scheduledAt = reminder.getLong("scheduledAt"),
                    title = reminder.getString("title"),
                    body = reminder.getString("body"),
                    persist = false,
                )
            } catch (_: Exception) {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .remove(key)
                    .apply()
            }
        }
    }
}
