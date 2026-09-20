package com.josepht2244.foraneo

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONObject

/** Persisted, local, inexact alarms. No server, exact-alarm privilege or polling. */
object ForaneoReminders {
    private const val CHANNEL = "foraneo_home_v2"
    private const val STORE = "foraneo_reminders"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Hogar y agenda", NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = "Productos que faltan y recordatorios que programaste en Foráneo"
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    fun show(context: Context, id: Int, title: String, body: String) {
        ensureChannel(context)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        val open = PendingIntent.getActivity(context, id, Intent(context, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP).putExtra("section", "agenda"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF0B3A31.toInt()).setContentTitle(title.take(180)).setContentText(body.take(800))
            .setStyle(Notification.BigTextStyle().bigText(body.take(800))).setContentIntent(open)
            .setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).setCategory(Notification.CATEGORY_REMINDER)
            .build()
        manager.notify(id, notification)
    }

    private fun alarmIntent(context: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(
        context, id, Intent(context, ReminderReceiver::class.java).setAction("com.josepht2244.foraneo.REMINDER").putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun schedule(context: Context, id: Int, title: String, body: String, at: Long) {
        if (at <= System.currentTimeMillis()) return
        val record = JSONObject().put("title", title.take(180)).put("body", body.take(800)).put("at", at)
        context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit().putString(id.toString(), record.toString()).apply()
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent(context, id))
    }

    fun cancel(context: Context, id: Int) {
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context, id))
        context.getSystemService(NotificationManager::class.java).cancel(id)
        context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit().remove(id.toString()).apply()
    }

    fun deliver(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
        val raw = prefs.getString(id.toString(), null) ?: return
        try {
            val record = JSONObject(raw)
            show(context, id, record.getString("title"), record.getString("body"))
        } finally {
            prefs.edit().remove(id.toString()).apply()
        }
    }

    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
        for ((key, value) in prefs.all) {
            val id = key.toIntOrNull() ?: continue
            try {
                val record = JSONObject(value as String)
                val at = record.getLong("at")
                if (at > System.currentTimeMillis()) schedule(context, id, record.getString("title"), record.getString("body"), at)
                else if (System.currentTimeMillis() - at < 24 * 60 * 60 * 1000) deliver(context, id)
                else prefs.edit().remove(key).apply()
            } catch (_: Exception) { prefs.edit().remove(key).apply() }
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.josepht2244.foraneo.REMINDER") return
        try { ForaneoReminders.deliver(context, intent.getIntExtra("id", 0)) } catch (_: Exception) { /* Corrupt legacy reminder must not crash app. */ }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
            ForaneoReminders.restore(context)
            ForaneoWidget.updateAll(context)
        }
    }
}
