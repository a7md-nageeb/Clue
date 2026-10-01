package com.forgottenthings.forgotten_things

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

/** Edit-widget screen: picks which categories this widget shows as chips. */
class WidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        // Cancelling still keeps the widget; it just falls back to most-used chips.
        setResult(RESULT_OK, resultIntent())

        val categories = WidgetDataStore.loadSnapshot(this)?.categories.orEmpty()
        if (categories.isEmpty()) {
            AlertDialog.Builder(this)
                .setTitle(R.string.widget_configure_title)
                .setMessage(R.string.widget_configure_empty)
                .setPositiveButton(android.R.string.ok, null)
                .setOnDismissListener { finish() }
                .show()
            return
        }

        val preferred = WidgetDataStore.preferredChips(this, appWidgetId)
        val labels = categories.map {
            getString(R.string.widget_configure_item_count, WidgetDataStore.displayName(it.icon), it.count)
        }.toTypedArray()
        val checked = BooleanArray(categories.size) { categories[it].icon in preferred }

        AlertDialog.Builder(this)
            .setTitle(R.string.widget_configure_title)
            .setMultiChoiceItems(labels, checked) { _, index, isChecked -> checked[index] = isChecked }
            .setPositiveButton(R.string.widget_configure_save) { _, _ ->
                save(categories.filterIndexed { index, _ -> checked[index] }.map { it.icon })
            }
            .setNeutralButton(R.string.widget_configure_most_used) { _, _ -> save(emptyList()) }
            .setNegativeButton(android.R.string.cancel, null)
            .setOnDismissListener { finish() }
            .show()
    }

    private fun save(icons: List<String>) {
        if (icons.isEmpty()) {
            WidgetDataStore.clearPreferredChips(this, appWidgetId)
        } else {
            WidgetDataStore.setPreferredChips(this, appWidgetId, icons)
        }
        ForgottenThingsWidgetProvider.refreshAll(this)
    }

    private fun resultIntent() =
        Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
}
