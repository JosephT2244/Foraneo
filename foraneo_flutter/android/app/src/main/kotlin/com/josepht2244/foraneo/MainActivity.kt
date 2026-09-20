package com.josepht2244.foraneo

import android.Manifest
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Reconcile persisted alarms when a force-stopped app is opened again.
        ForaneoReminders.restore(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.josepht2244.foraneo/home")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getStatus" -> {
                            val manager = AppWidgetManager.getInstance(this)
                            val widgets = listOf(ForaneoWidget::class.java, ShoppingWidget::class.java, AgendaWidget::class.java, KitchenWidget::class.java)
                            result.success(mapOf("notificationsEnabled" to getSystemService(NotificationManager::class.java).areNotificationsEnabled(), "pendingReminders" to getSharedPreferences("foraneo_reminders", MODE_PRIVATE).all.size, "widgetInstances" to widgets.sumOf { manager.getAppWidgetIds(ComponentName(this, it)).size }, "widgetProviders" to widgets.size))
                        }
                        "requestNotifications" -> {
                            ForaneoReminders.ensureChannel(this)
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                if (notificationResult != null) {
                                    result.success(false)
                                } else {
                                    notificationResult = result
                                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 612)
                                }
                            } else result.success(getSystemService(NotificationManager::class.java).areNotificationsEnabled())
                        }
                        "notify" -> {
                            ForaneoReminders.show(this, call.argument<Number>("id")!!.toInt(), call.argument<String>("title") ?: "Foráneo", call.argument<String>("body") ?: "")
                            result.success(null)
                        }
                        "schedule" -> {
                            ForaneoReminders.schedule(this, call.argument<Number>("id")!!.toInt(), call.argument<String>("title") ?: "Foráneo", call.argument<String>("body") ?: "", call.argument<Number>("at")!!.toLong())
                            result.success(null)
                        }
                        "cancel" -> {
                            ForaneoReminders.cancel(this, call.argument<Number>("id")!!.toInt())
                            result.success(null)
                        }
                        "updateWidget" -> {
                            val edit = getSharedPreferences("foraneo_widgets", MODE_PRIVATE).edit()
                            for (key in listOf("shopping", "urgent", "tasks", "meal")) edit.putString(key, (call.argument<String>(key) ?: "").take(1400))
                            for (key in listOf("taskDays", "mealDays")) {
                                val days = call.argument<Map<String, String>>(key) ?: emptyMap()
                                val safeDays = days.filterKeys { it.matches(Regex("\\d{4}-\\d{2}-\\d{2}")) }.entries.take(400).associate { it.key to it.value.take(1400) }
                                edit.putString(key, org.json.JSONObject(safeDays).toString())
                            }
                            edit.putLong("updatedAt", System.currentTimeMillis()).apply()
                            ForaneoWidget.updateAll(this)
                            result.success(null)
                        }
                        "pinWidget" -> {
                            val type = call.argument<String>("type") ?: "summary"
                            val provider = when (type) {
                                "shopping" -> ShoppingWidget::class.java
                                "agenda" -> AgendaWidget::class.java
                                "kitchen" -> KitchenWidget::class.java
                                else -> ForaneoWidget::class.java
                            }
                            val manager = AppWidgetManager.getInstance(this)
                            result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported && manager.requestPinAppWidget(ComponentName(this, provider), null, null))
                        }
                        "openNotificationSettings" -> {
                            val settingsIntent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName"))
                            startActivity(settingsIntent)
                            result.success(null)
                        }
                        "takeLaunchSection" -> {
                            result.success(intent.getStringExtra("section"))
                            intent.removeExtra("section")
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("FORANEO_NATIVE", "La función del sistema no está disponible: ${e.javaClass.simpleName}", null)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 612) {
            notificationResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            notificationResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
