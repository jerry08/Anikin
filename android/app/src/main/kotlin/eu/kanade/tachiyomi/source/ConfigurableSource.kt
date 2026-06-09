package eu.kanade.tachiyomi.source

import android.content.SharedPreferences

interface ConfigurableSource : Source {
    fun setupPreferenceScreen(screen: Any) = Unit
    fun setupPreferences(preferences: SharedPreferences) = Unit
}