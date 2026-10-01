package com.forgottenthings.forgotten_things

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.os.SystemClock
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.forgottenthings.forgotten_things/widget"
    private var methodChannel: MethodChannel? = null
    private var pendingCreate = false
    private var isWarmLaunch = false

    override fun onCreate(savedInstanceState: Bundle?) {
        val processAgeMs = SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime()
        isWarmLaunch = savedInstanceState == null && processAgeMs >= 2500L
        super.onCreate(savedInstanceState)
        captureCreateIntent(intent)
    }

    override fun getDartEntrypointArgs(): MutableList<String> {
        val args = super.getDartEntrypointArgs()?.toMutableList() ?: mutableListOf()
        if (isWarmLaunch) {
            args.add("warm")
        }
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    ForgottenThingsWidgetProvider.refreshAll(applicationContext)
                    result.success(null)
                }
                "consumePendingCopy" -> result.success(null)
                "getWidgetDataDirectory" -> {
                    val dir = WidgetDataStore.dataDirectory(applicationContext)
                    dir.mkdirs()
                    result.success(dir.absolutePath)
                }
                else -> result.notImplemented()
            }
        }
        if (pendingCreate) {
            pendingCreate = false
            methodChannel?.invokeMethod("openCreate", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isCreateIntent(intent)) {
            methodChannel?.invokeMethod("openCreate", null) ?: run { pendingCreate = true }
        }
    }

    private fun captureCreateIntent(intent: Intent?) {
        if (isCreateIntent(intent)) {
            pendingCreate = true
        }
    }

    private fun isCreateIntent(intent: Intent?): Boolean {
        val data: Uri? = intent?.data
        return data?.scheme == "forgotten-things" && data.host == "create"
    }
}
