package com.forgottenthings.forgotten_things

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.forgottenthings.forgotten_things/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                updateAllWidgets()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun updateAllWidgets() {
        val context = applicationContext
        
        // 1. Notify OS to call onUpdate for all widgets
        val intent = Intent(context, ForgottenThingsWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, ForgottenThingsWidgetProvider::class.java)
            )
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
        
        // 2. Notify OS that the list data has changed to refresh ListView adapter
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, ForgottenThingsWidgetProvider::class.java)
        appWidgetManager.notifyAppWidgetViewDataChanged(
            appWidgetManager.getAppWidgetIds(componentName),
            R.id.widget_list
        )
    }
}

