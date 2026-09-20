package com.josepht2244.foraneo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONObject

open class ForaneoWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateProvider(context, manager, javaClass, ids)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            for (provider in listOf(ForaneoWidget::class.java, ShoppingWidget::class.java, AgendaWidget::class.java, KitchenWidget::class.java)) {
                updateProvider(context, manager, provider, manager.getAppWidgetIds(ComponentName(context, provider)))
            }
        }

        private fun updateProvider(context: Context, manager: AppWidgetManager, provider: Class<*>, ids: IntArray) {
            val prefs = context.getSharedPreferences("foraneo_widgets", Context.MODE_PRIVATE)
            val kind = when (provider) {
                ShoppingWidget::class.java -> "shopping"
                AgendaWidget::class.java -> "agenda"
                KitchenWidget::class.java -> "kitchen"
                else -> "summary"
            }
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.foraneo_widget)
                val title = when (kind) { "shopping" -> "Mis compras"; "agenda" -> "Mi agenda"; "kitchen" -> "En mi cocina"; else -> "Mi hogar" }
                views.setTextViewText(R.id.widget_title, "Foráneo · $title")
                val updated = prefs.getLong("updatedAt", 0)
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val today = dateFormat.format(Date())
                fun datedText(daysKey: String, fallbackKey: String, empty: String): String {
                    val days = try { JSONObject(prefs.getString(daysKey, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
                    if (days.has(today)) return days.optString(today).ifBlank { empty }
                    if (days.length() > 0) return empty
                    return if (updated > 0L && dateFormat.format(Date(updated)) == today) prefs.getString(fallbackKey, "")?.ifBlank { empty } ?: empty
                    else "Abre Foráneo para actualizar el día"
                }
                views.setTextViewText(R.id.widget_updated, if (updated == 0L) "Activa los widgets en Ajustes" else "Actualizado " + SimpleDateFormat("dd MMM · HH:mm", Locale("es", "MX")).format(Date(updated)))
                views.setTextViewText(R.id.widget_urgent, prefs.getString("urgent", "")?.ifBlank { "Sin compras urgentes" })
                views.setTextViewText(R.id.widget_shopping, prefs.getString("shopping", "")?.ifBlank { "Tu despensa está al día" })
                views.setTextViewText(R.id.widget_tasks, datedText("taskDays", "tasks", "Sin pendientes para hoy"))
                views.setTextViewText(R.id.widget_meal, datedText("mealDays", "meal", "Planea algo rico en Cocina"))
                views.setViewVisibility(R.id.shopping_group, if (kind == "summary" || kind == "shopping") View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.agenda_group, if (kind == "summary" || kind == "agenda") View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.kitchen_group, if (kind == "summary" || kind == "kitchen") View.VISIBLE else View.GONE)
                fun open(section: String, code: Int) = PendingIntent.getActivity(context, id * 10 + code, Intent(context, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP).putExtra("section", section), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, open(kind, 0))
                views.setOnClickPendingIntent(R.id.shopping_group, open("shopping", 1))
                views.setOnClickPendingIntent(R.id.agenda_group, open("agenda", 2))
                views.setOnClickPendingIntent(R.id.kitchen_group, open("kitchen", 3))
                manager.updateAppWidget(id, views)
            }
        }
    }
}

class ShoppingWidget : ForaneoWidget()
class AgendaWidget : ForaneoWidget()
class KitchenWidget : ForaneoWidget()
