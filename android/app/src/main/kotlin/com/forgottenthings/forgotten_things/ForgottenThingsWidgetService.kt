package com.forgottenthings.forgotten_things

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.io.File
import java.util.ArrayList

class ForgottenThingsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ForgottenThingsWidgetFactory(applicationContext)
    }
}

class ForgottenThingsWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var itemsList = ArrayList<WidgetItem>()

    data class WidgetItem(
        val id: String,
        val title: String,
        val content: String,
        val icon: String?,
        val isPinned: Boolean
    )

    override fun onCreate() {
        loadDataFromDb()
    }

    override fun onDataSetChanged() {
        loadDataFromDb()
    }

    private fun loadDataFromDb() {
        val newList = ArrayList<WidgetItem>()
        try {
            // Bulletproof database path discovery
            var dbFile = File(context.filesDir, "db.sqlite")
            if (!dbFile.exists()) {
                dbFile = File(context.filesDir.parentFile, "app_flutter/db.sqlite")
            }
            if (!dbFile.exists()) {
                dbFile = File(context.filesDir, "app_flutter/db.sqlite")
            }

            if (dbFile.exists()) {
                val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
                // Query active items (not deleted), ordered by is_pinned first, then by updated_at desc
                val cursor = db.rawQuery(
                    "SELECT id, title, content, icon, is_pinned FROM items WHERE deleted_at IS NULL ORDER BY is_pinned DESC, updated_at DESC",
                    null
                )
                if (cursor != null) {
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(0)
                        val title = cursor.getString(1)
                        val content = cursor.getString(2)
                        val icon = cursor.getString(3)
                        val isPinned = cursor.getInt(4) == 1
                        newList.add(WidgetItem(id, title, content, icon, isPinned))
                    }
                    cursor.close()
                }
                db.close()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        itemsList = newList
    }

    override fun onDestroy() {
        itemsList.clear()
    }

    override fun getCount(): Int = itemsList.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= itemsList.size) {
            return RemoteViews(context.packageName, R.layout.widget_list_item)
        }
        val item = itemsList[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_list_item)

        rv.setTextViewText(R.id.item_title, item.title)
        rv.setTextViewText(R.id.item_content, item.content)

        // Set category icon with correct resource mapping
        val iconRes = when (item.icon) {
            "link" -> R.drawable.ic_link
            "plus" -> R.drawable.ic_plus
            else -> R.drawable.ic_note
        }
        rv.setImageViewResource(R.id.item_icon, iconRes)

        // 1. Copy action (clicking the copy icon copies the text to clipboard)
        val copyFillIn = Intent().apply {
            action = ForgottenThingsWidgetProvider.ACTION_COPY
            putExtra(ForgottenThingsWidgetProvider.EXTRA_ITEM_TITLE, item.title)
            putExtra(ForgottenThingsWidgetProvider.EXTRA_ITEM_CONTENT, item.content)
        }
        rv.setOnClickFillInIntent(R.id.item_copy_btn, copyFillIn)

        // 2. Open action (clicking the item body launches the app)
        val openFillIn = Intent().apply {
            action = Intent.ACTION_VIEW
            putExtra("itemId", item.id)
        }
        rv.setOnClickFillInIntent(R.id.item_root, openFillIn)

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
