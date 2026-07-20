package com.oneb.anikin.extensions

import android.content.SharedPreferences
import androidx.preference.PreferenceDataStore

/**
 * Bridges androidx preference widgets to the `source_<id>` SharedPreferences file that
 * extensions read directly, so values changed in the UI are visible to the source.
 */
class SharedPreferencesDataStore(private val prefs: SharedPreferences) : PreferenceDataStore() {

    override fun getBoolean(key: String, defValue: Boolean): Boolean = prefs.getBoolean(key, defValue)

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun getInt(key: String, defValue: Int): Int = prefs.getInt(key, defValue)

    override fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }

    override fun getLong(key: String, defValue: Long): Long = prefs.getLong(key, defValue)

    override fun putLong(key: String, value: Long) {
        prefs.edit().putLong(key, value).apply()
    }

    override fun getFloat(key: String, defValue: Float): Float = prefs.getFloat(key, defValue)

    override fun putFloat(key: String, value: Float) {
        prefs.edit().putFloat(key, value).apply()
    }

    override fun getString(key: String, defValue: String?): String? = prefs.getString(key, defValue)

    override fun putString(key: String, value: String?) {
        prefs.edit().putString(key, value).apply()
    }

    override fun getStringSet(key: String, defValues: Set<String>?): Set<String>? =
        prefs.getStringSet(key, defValues)

    override fun putStringSet(key: String, values: Set<String>?) {
        prefs.edit().putStringSet(key, values).apply()
    }
}
