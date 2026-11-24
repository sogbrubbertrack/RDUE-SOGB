package com.example.rubberway

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class FormationReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            FormationReminderScheduler.rescheduleAfterRestart(context)
        }
    }
}
