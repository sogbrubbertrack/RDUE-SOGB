package com.example.rubberway

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class FormationReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(FormationReminderScheduler.EXTRA_ID, 0)
        val title = intent.getStringExtra(FormationReminderScheduler.EXTRA_TITLE)
            ?: "Formation RubberWay"
        val body = intent.getStringExtra(FormationReminderScheduler.EXTRA_BODY)
            ?: "Une formation de planteur est prévue aujourd’hui."

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "formation_reminders"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Rappels de formation",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }

        val openApp = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = openApp?.let {
            PendingIntent.getActivity(
                context,
                id,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
        if (contentIntent != null) builder.setContentIntent(contentIntent)
        manager.notify(id, builder.build())

        FormationReminderScheduler.cancel(context, id)
    }
}
