package com.forgottenthings.forgotten_things

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class WidgetCategory(
    val icon: String,
    val count: Int,
)

data class WidgetItem(
    val id: String,
    val title: String,
    val content: String,
    val icon: String,
    val isPinned: Boolean,
    val hasTitle: Boolean,
    val displayTitle: String,
)

data class WidgetSnapshot(
    val totalCount: Int,
    val categories: List<WidgetCategory>,
    val items: List<WidgetItem>,
)

object WidgetDataStore {
    const val PREFS_NAME = "clue_widget_prefs"
    const val KEY_FILTER = "widget_filter_icon"

    fun dataDirectory(context: Context): File = File(context.filesDir, "widget_data")

    fun snapshotFile(context: Context): File = File(dataDirectory(context), "snapshot.json")

    fun logoFile(context: Context): File = File(dataDirectory(context), "logo.png")

    fun copyFile(context: Context): File = File(dataDirectory(context), "copy.png")

    fun iconFile(context: Context, icon: String): File {
        val safe = icon.replace(Regex("[^a-zA-Z0-9_-]"), "_")
        return File(File(dataDirectory(context), "icons"), "$safe.png")
    }

    fun selectedFilter(context: Context): String? {
        val value = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_FILTER, null)
        return value?.takeIf { it.isNotBlank() }
    }

    fun setSelectedFilter(context: Context, icon: String?) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_FILTER, icon)
            .apply()
    }

    /** Tapping the selected chip, or "All", clears the filter. */
    fun toggleFilter(context: Context, icon: String) {
        val next = if (icon.isEmpty() || selectedFilter(context) == icon) null else icon
        setSelectedFilter(context, next)
    }

    /** The saved filter, or null when its category no longer has any items. */
    fun activeFilter(context: Context, snapshot: WidgetSnapshot): String? {
        val filter = selectedFilter(context) ?: return null
        return filter.takeIf { snapshot.categories.any { it.icon == filter } }
    }

    fun matchingItems(context: Context, snapshot: WidgetSnapshot): List<WidgetItem> {
        val filter = activeFilter(context, snapshot)
        val items = if (filter == null) snapshot.items else snapshot.items.filter { it.icon == filter }
        return items.filter { it.isPinned } + items.filterNot { it.isPinned }
    }

    /** The categories picked for this widget that still exist, otherwise most-used first. */
    fun chipCategories(snapshot: WidgetSnapshot, preferred: List<String>): List<WidgetCategory> {
        val picked = preferred.distinct().mapNotNull { icon ->
            snapshot.categories.firstOrNull { it.icon == icon }
        }
        return picked.ifEmpty { snapshot.categories }
    }

    fun preferredChips(context: Context, appWidgetId: Int): List<String> {
        val value = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(chipsKey(appWidgetId), null)
        return value?.split(',')?.filter { it.isNotBlank() }.orEmpty()
    }

    fun setPreferredChips(context: Context, appWidgetId: Int, icons: List<String>) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(chipsKey(appWidgetId), icons.joinToString(","))
            .apply()
    }

    fun clearPreferredChips(context: Context, appWidgetId: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(chipsKey(appWidgetId))
            .apply()
    }

    private fun chipsKey(appWidgetId: Int) = "widget_chips_$appWidgetId"

    /** "person-square" -> "Person square", "stickyNote" -> "Sticky note". */
    fun displayName(icon: String): String {
        val words = mutableListOf<String>()
        val current = StringBuilder()
        for (character in icon) {
            if (character == '-' || character == '_' || character.isUpperCase()) {
                if (current.isNotEmpty()) words.add(current.toString())
                current.clear()
                if (character.isUpperCase()) current.append(character)
            } else {
                current.append(character)
            }
        }
        if (current.isNotEmpty()) words.add(current.toString())
        return words.joinToString(" ") { it.lowercase() }.replaceFirstChar { it.uppercase() }
    }

    fun decodeBitmap(file: File, maxPx: Int = 128): Bitmap? {
        if (!file.exists()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / sample > maxPx || bounds.outHeight / sample > maxPx) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(file.absolutePath, opts)
    }

    fun loadSnapshot(context: Context): WidgetSnapshot? {
        val file = snapshotFile(context)
        if (!file.exists()) return null
        return try {
            val root = JSONObject(file.readText())
            val categories = mutableListOf<WidgetCategory>()
            val categoryArray = root.optJSONArray("categories") ?: JSONArray()
            for (i in 0 until categoryArray.length()) {
                val obj = categoryArray.getJSONObject(i)
                categories.add(
                    WidgetCategory(
                        icon = obj.optString("icon", "note"),
                        count = obj.optInt("count", 0),
                    )
                )
            }
            val items = mutableListOf<WidgetItem>()
            val itemArray = root.optJSONArray("items") ?: JSONArray()
            for (i in 0 until itemArray.length()) {
                val obj = itemArray.getJSONObject(i)
                val title = obj.optString("title", "")
                val content = obj.optString("content", "")
                val hasTitle = obj.optBoolean("hasTitle", title.isNotBlank())
                items.add(
                    WidgetItem(
                        id = obj.optString("id"),
                        title = title,
                        content = content,
                        icon = obj.optString("icon", "note"),
                        isPinned = obj.optBoolean("isPinned", false),
                        hasTitle = hasTitle,
                        displayTitle = obj.optString(
                            "displayTitle",
                            if (hasTitle) title else content,
                        ),
                    )
                )
            }
            WidgetSnapshot(
                totalCount = root.optInt("totalCount", items.size),
                categories = categories,
                items = items,
            )
        } catch (_: Exception) {
            null
        }
    }
}
