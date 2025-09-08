package com.example.first_flutter_yjpark.alarm

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class AlarmItem(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val label: String,
    val daysOfWeek: List<Int> // ISO 1=Mon ... 7=Sun
)

object AlarmStore {
    private const val PREF = "alarm_store"
    private const val KEY = "alarms"

    fun save(context: Context, items: List<AlarmItem>) {
        val arr = JSONArray()
        items.forEach {
            arr.put(JSONObject().apply {
                put("id", it.id)
                put("hour", it.hour)
                put("minute", it.minute)
                put("label", it.label)
                put("days", JSONArray(it.daysOfWeek))
            })
        }
        context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }

    fun load(context: Context): List<AlarmItem> {
        val raw = context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
            .getString(KEY, "[]") ?: "[]"
        val arr = JSONArray(raw)
        val out = mutableListOf<AlarmItem>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val daysJson = o.optJSONArray("days") ?: JSONArray()
            val days = MutableList(daysJson.length()) { idx -> daysJson.getInt(idx) }
            out += AlarmItem(
                o.getInt("id"),
                o.getInt("hour"),
                o.getInt("minute"),
                o.optString("label", "약 복용"),
                days
            )
        }
        return out
    }

    fun upsert(context: Context, item: AlarmItem) {
        val list = load(context).toMutableList()
        val idx = list.indexOfFirst { it.id == item.id }
        if (idx >= 0) list[idx] = item else list += item
        save(context, list)
    }

    fun remove(context: Context, id: Int) {
        save(context, load(context).filterNot { it.id == id })
    }

    fun removeMany(context: Context, ids: List<Int>) {
        val all = load(context).filterNot { ids.contains(it.id) }
        save(context, all)
    }
}
