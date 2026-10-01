package com.forgottenthings.forgotten_things

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class ForgottenThingsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val EXTRA_ITEM_ID = "com.forgottenthings.forgotten_things.EXTRA_ITEM_ID"
        const val EXTRA_ITEM_CONTENT = "com.forgottenthings.forgotten_things.EXTRA_ITEM_CONTENT"
        const val ACTION_COPY = "com.forgottenthings.forgotten_things.action.COPY"
        private const val ACTION_FILTER = "com.forgottenthings.forgotten_things.action.FILTER"
        private const val EXTRA_FILTER_ICON = "com.forgottenthings.forgotten_things.EXTRA_FILTER_ICON"
        private const val TAG = "ClueWidget"

        // Chip fitting, in dp. The chip width matches @dimen/widget_chip_width.
        private const val WIDGET_PADDING_DP = 16
        private const val CHIP_WIDTH_DP = 56
        private const val ALL_CHIP_WIDTH_DP = 72
        private const val CHIP_GAP_DP = 6
        private const val DEFAULT_WIDTH_DP = 250

        fun copyUri(itemId: String): Uri =
            Uri.Builder()
                .scheme("clue-widget")
                .authority("copy")
                .appendPath(itemId)
                .build()

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ForgottenThingsWidgetProvider::class.java)
            )
            if (ids.isEmpty()) return
            @Suppress("DEPRECATION")
            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list_view)
            val intent = Intent(context, ForgottenThingsWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_FILTER) {
            WidgetDataStore.toggleFilter(context, intent.getStringExtra(EXTRA_FILTER_ICON).orEmpty())
            refreshAll(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { WidgetDataStore.clearPreferredChips(context, it) }
        super.onDeleted(context, appWidgetIds)
    }

    private fun render(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = try {
            buildViews(context, appWidgetManager, appWidgetId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to build widget $appWidgetId", e)
            RemoteViews(context.packageName, R.layout.widget_fallback)
        }
        try {
            appWidgetManager.updateAppWidget(appWidgetId, views)
            @Suppress("DEPRECATION")
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply widget $appWidgetId", e)
            appWidgetManager.updateAppWidget(
                appWidgetId,
                RemoteViews(context.packageName, R.layout.widget_fallback),
            )
        }
    }

    private fun buildViews(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_list)

        val openApp = PendingIntent.getActivity(
            context,
            appWidgetId,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            },
            immutableFlags(),
        )
        views.setOnClickPendingIntent(R.id.widget_logo, openApp)
        views.setOnClickPendingIntent(R.id.widget_title, openApp)

        WidgetDataStore.decodeBitmap(WidgetDataStore.logoFile(context), maxPx = 270)?.let { logo ->
            views.setImageViewBitmap(R.id.widget_logo, logo)
            views.setViewVisibility(R.id.widget_logo, View.VISIBLE)
            views.setViewVisibility(R.id.widget_title, View.GONE)
        } ?: run {
            views.setViewVisibility(R.id.widget_logo, View.GONE)
            views.setViewVisibility(R.id.widget_title, View.VISIBLE)
        }

        val snapshot = WidgetDataStore.loadSnapshot(context)
        if (snapshot != null && snapshot.items.isNotEmpty()) {
            val widthDp = appWidgetManager.getAppWidgetOptions(appWidgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, DEFAULT_WIDTH_DP)
                .takeIf { it > 0 } ?: DEFAULT_WIDTH_DP
            bindChips(context, views, appWidgetId, snapshot, widthDp)
        } else {
            views.setViewVisibility(R.id.widget_chip_row_1, View.GONE)
            views.setViewVisibility(R.id.widget_chip_row_2, View.GONE)
        }

        views.setEmptyView(R.id.widget_list_view, R.id.widget_empty_view)
        views.setPendingIntentTemplate(R.id.widget_list_view, copyTemplate(context, appWidgetId))
        bindItems(context, views, appWidgetId)
        return views
    }

    private fun bindChips(
        context: Context,
        views: RemoteViews,
        appWidgetId: Int,
        snapshot: WidgetSnapshot,
        widthDp: Int,
    ) {
        val activeFilter = WidgetDataStore.activeFilter(context, snapshot)
        val (firstRow, secondRow) = chipRows(
            categories = WidgetDataStore.chipCategories(
                snapshot,
                WidgetDataStore.preferredChips(context, appWidgetId),
            ),
            selected = snapshot.categories.firstOrNull { it.icon == activeFilter },
            contentWidthDp = widthDp - WIDGET_PADDING_DP * 2,
        )

        views.removeAllViews(R.id.widget_chip_row_1)
        views.addView(
            R.id.widget_chip_row_1,
            chipView(context, appWidgetId, icon = null, count = snapshot.items.size, activeFilter),
        )
        firstRow.forEach {
            views.addView(R.id.widget_chip_row_1, chipView(context, appWidgetId, it.icon, it.count, activeFilter))
        }
        views.setViewVisibility(R.id.widget_chip_row_1, View.VISIBLE)

        views.removeAllViews(R.id.widget_chip_row_2)
        secondRow.forEach {
            views.addView(R.id.widget_chip_row_2, chipView(context, appWidgetId, it.icon, it.count, activeFilter))
        }
        views.setViewVisibility(
            R.id.widget_chip_row_2,
            if (secondRow.isEmpty()) View.GONE else View.VISIBLE,
        )
    }

    /**
     * One row when everything fits beside "All", otherwise two. [selected] replaces the
     * last visible chip when it would otherwise be cut off.
     */
    private fun chipRows(
        categories: List<WidgetCategory>,
        selected: WidgetCategory?,
        contentWidthDp: Int,
    ): Pair<List<WidgetCategory>, List<WidgetCategory>> {
        val slot = CHIP_WIDTH_DP + CHIP_GAP_DP
        val besideAll = maxOf(0, (contentWidthDp - ALL_CHIP_WIDTH_DP - CHIP_GAP_DP) / slot)
        val fullRow = maxOf(1, contentWidthDp / slot)
        val limit = if (categories.size <= besideAll) besideAll else besideAll + fullRow

        val visible = categories.take(limit).toMutableList()
        if (selected != null && selected !in visible) {
            if (visible.size < limit) {
                visible.add(selected)
            } else if (visible.isNotEmpty()) {
                visible[visible.lastIndex] = selected
            }
        }
        return visible.take(besideAll) to visible.drop(besideAll)
    }

    private fun chipView(
        context: Context,
        appWidgetId: Int,
        icon: String?,
        count: Int,
        activeFilter: String?,
    ): RemoteViews {
        val isSelected = activeFilter == icon
        val chip = RemoteViews(
            context.packageName,
            if (isSelected) R.layout.widget_chip_selected else R.layout.widget_chip,
        )
        if (icon == null) {
            chip.setTextViewText(R.id.chip_label, context.getString(R.string.widget_chip_all, count))
            chip.setContentDescription(
                R.id.chip_root,
                context.getString(R.string.widget_chip_all_description, count),
            )
        } else {
            chip.setTextViewText(R.id.chip_label, count.toString())
            WidgetDataStore.decodeBitmap(WidgetDataStore.iconFile(context, icon), maxPx = 48)?.let {
                chip.setImageViewBitmap(R.id.chip_icon, it)
                chip.setViewVisibility(R.id.chip_icon, View.VISIBLE)
            }
            chip.setContentDescription(
                R.id.chip_root,
                context.getString(
                    R.string.widget_chip_description,
                    count,
                    WidgetDataStore.displayName(icon),
                ),
            )
        }

        val filterIntent = Intent(context, ForgottenThingsWidgetProvider::class.java).apply {
            action = ACTION_FILTER
            data = Uri.parse("clue-widget://filter/$appWidgetId/${Uri.encode(icon.orEmpty())}")
            putExtra(EXTRA_FILTER_ICON, icon.orEmpty())
        }
        chip.setOnClickPendingIntent(
            R.id.chip_root,
            PendingIntent.getBroadcast(context, 0, filterIntent, immutableFlags()),
        )
        return chip
    }

    private fun bindItems(context: Context, views: RemoteViews, appWidgetId: Int) {
        val serviceIntent = Intent(context, ForgottenThingsWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("clue-widget://list/$appWidgetId")
        }
        @Suppress("DEPRECATION")
        views.setRemoteAdapter(R.id.widget_list_view, serviceIntent)
    }

    private fun copyTemplate(context: Context, appWidgetId: Int): PendingIntent {
        // Leave data unset so each row's fill-in URI can supply the item id.
        val intent = Intent(context, WidgetCopyActivity::class.java).apply {
            action = ACTION_COPY
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_NO_ANIMATION or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        }
        return PendingIntent.getActivity(context, 10_000 + appWidgetId, intent, mutableFlags())
    }

    private fun immutableFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    private fun mutableFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return flags
    }
}
