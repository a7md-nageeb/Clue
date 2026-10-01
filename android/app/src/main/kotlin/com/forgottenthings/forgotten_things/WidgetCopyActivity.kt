package com.forgottenthings.forgotten_things

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Toast

class WidgetCopyActivity : Activity() {
    private var completed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        completed = false
    }

    override fun onResume() {
        super.onResume()
        window.decorView.post { complete(attempt = 0) }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) complete(attempt = 0)
    }

    private fun complete(attempt: Int) {
        if (completed) return
        // Clipboard writes are rejected until this activity is the focused window.
        if (!hasWindowFocus() && attempt < 10) {
            window.decorView.postDelayed({ complete(attempt + 1) }, 30)
            return
        }
        completed = true
        val content = resolveContent()
        if (content.isNotEmpty()) {
            try {
                val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("Clue", content))
                val preview = if (content.length > 25) "${content.take(25)}..." else content
                Toast.makeText(applicationContext, "Copied: $preview", Toast.LENGTH_SHORT).show()
            } catch (e: Exception) {
                Log.e(TAG, "Clipboard write failed", e)
                Toast.makeText(applicationContext, "Couldn't copy", Toast.LENGTH_SHORT).show()
            }
        } else {
            Log.w(TAG, "Widget copy opened without an item. data=${intent.data}")
        }
        finish()
        overridePendingTransition(0, 0)
    }

    private fun resolveContent(): String {
        val extra = intent.getStringExtra(ForgottenThingsWidgetProvider.EXTRA_ITEM_CONTENT)
        if (!extra.isNullOrEmpty()) return extra
        val id = itemId() ?: return ""
        val item = WidgetDataStore.loadSnapshot(this)?.items?.firstOrNull { it.id == id } ?: return ""
        return item.content.ifBlank { item.displayTitle }
    }

    private fun itemId(): String? {
        intent.getStringExtra(ForgottenThingsWidgetProvider.EXTRA_ITEM_ID)
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
        val data = intent.data ?: return null
        if (data.scheme != "clue-widget" || data.host != "copy") return null
        return data.pathSegments.firstOrNull()?.takeIf { it.isNotEmpty() }
    }

    companion object {
        private const val TAG = "ClueWidget"
    }
}
