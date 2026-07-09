package com.forgottenthings.forgotten_things

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ClipboardManager
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.Toast
import android.content.ComponentName
import android.os.Build

class ForgottenThingsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_COPY = "com.forgottenthings.forgotten_things.ACTION_COPY"
        const val EXTRA_ITEM_CONTENT = "com.forgottenthings.forgotten_things.EXTRA_ITEM_CONTENT"
        const val EXTRA_ITEM_TITLE = "com.forgottenthings.forgotten_things.EXTRA_ITEM_TITLE"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_list)

            // Bind the ListView to our service
            val intent = Intent(context, ForgottenThingsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, intent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty_view)

            // Setup PendingIntent template for list items.
            // Templates MUST be mutable as list items merge their fill-in intent extras with it.
            val clickIntent = Intent(context, ForgottenThingsWidgetProvider::class.java)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val clickPendingIntent = PendingIntent.getBroadcast(context, 0, clickIntent, flags)
            views.setPendingIntentTemplate(R.id.widget_list, clickPendingIntent)

            // Setup PendingIntent for the "Add/Plus" button to open the main app
            val appIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val appFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val appPendingIntent = PendingIntent.getActivity(context, 0, appIntent, appFlags)
            views.setOnClickPendingIntent(R.id.widget_header_add, appPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_COPY) {
            val title = intent.getStringExtra(EXTRA_ITEM_TITLE) ?: "Item"
            val content = intent.getStringExtra(EXTRA_ITEM_CONTENT) ?: ""
            if (content.isNotEmpty()) {
                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("Clue Content", content)
                clipboard.setPrimaryClip(clip)

                val displayContent = if (content.length > 25) "${content.take(25)}..." else content
                Toast.makeText(context, "Copied: $displayContent", Toast.LENGTH_SHORT).show()
            }
        } else if (intent.action == Intent.ACTION_VIEW) {
            // Trigger MainActivity
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(appIntent)
        }
        super.onReceive(context, intent)
    }
}
