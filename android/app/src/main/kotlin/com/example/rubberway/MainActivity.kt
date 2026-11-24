package com.example.rubberway

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.rubberway/formation_reminders"
    private val notificationPermissionRequestCode = 8041

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleReminder" -> {
                        val id = call.argument<Int>("id")
                        val scheduledAt = call.argument<Long>("scheduledAt")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        if (id == null || scheduledAt == null || title == null || body == null) {
                            result.error("INVALID_ARGUMENTS", "Paramètres de rappel incomplets.", null)
                            return@setMethodCallHandler
                        }
                        FormationReminderScheduler.schedule(this, id, scheduledAt, title, body)
                        val permissionGranted = if (Build.VERSION.SDK_INT < 33) {
                            true
                        } else {
                            val granted = checkSelfPermission(
                                Manifest.permission.POST_NOTIFICATIONS,
                            ) == PackageManager.PERMISSION_GRANTED
                            if (!granted) {
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    notificationPermissionRequestCode,
                                )
                            }
                            granted
                        }
                        result.success(permissionGranted)
                    }
                    "cancelReminder" -> {
                        val id = call.argument<Int>("id")
                        if (id == null) {
                            result.error("INVALID_ARGUMENTS", "Identifiant de rappel manquant.", null)
                        } else {
                            FormationReminderScheduler.cancel(this, id)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
