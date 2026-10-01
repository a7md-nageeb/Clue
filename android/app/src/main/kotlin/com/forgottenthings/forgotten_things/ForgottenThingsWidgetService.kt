package com.forgottenthings.forgotten_things

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class ForgottenThingsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ForgottenThingsWidgetFactory(applicationContext)
    }
}

object WidgetItemRemoteViews {
    fun create(context: Context, item: WidgetItem): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)
        val title = SpannableString(item.displayTitle)
        if (item.hasTitle) {
            title.setSpan(StyleSpan(Typeface.BOLD), 0, title.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        views.setTextViewText(R.id.item_title, title)
        WidgetDataStore.decodeBitmap(WidgetDataStore.iconFile(context, item.icon), maxPx = 48)
            ?.let { views.setImageViewBitmap(R.id.item_icon, it) }

        val copyContent = item.content.ifBlank { item.displayTitle }
        val fillIn = Intent().apply {
            action = ForgottenThingsWidgetProvider.ACTION_COPY
            data = ForgottenThingsWidgetProvider.copyUri(item.id)
            putExtra(ForgottenThingsWidgetProvider.EXTRA_ITEM_ID, item.id)
            putExtra(ForgottenThingsWidgetProvider.EXTRA_ITEM_CONTENT, copyContent)
        }
        views.setOnClickFillInIntent(R.id.item_card, fillIn)
        return views
    }
}

class ForgottenThingsWidgetFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var items = emptyList<WidgetItem>()

    override fun onCreate() {
        loadItems()
    }

    override fun onDataSetChanged() {
        loadItems()
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position !in items.indices) {
            return RemoteViews(context.packageName, R.layout.widget_list_item)
        }
        return WidgetItemRemoteViews.create(context, items[position])
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        return items.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()
    }

    override fun hasStableIds(): Boolean = true

    private fun loadItems() {
        items = WidgetDataStore.loadSnapshot(context)
            ?.let { WidgetDataStore.matchingItems(context, it) }
            .orEmpty()
    }
}
