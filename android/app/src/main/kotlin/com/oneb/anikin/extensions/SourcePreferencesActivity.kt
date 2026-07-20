package com.oneb.anikin.extensions

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.core.os.bundleOf
import androidx.lifecycle.lifecycleScope
import androidx.preference.PreferenceFragmentCompat
import kotlinx.coroutines.launch

/**
 * Hosts the androidx preference screen a ConfigurableAnimeSource/ConfigurableSource builds,
 * mirroring how Aniyomi and Dantotsu expose per-source settings.
 */
class SourcePreferencesActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val providerKey = intent.getStringExtra(EXTRA_PROVIDER_KEY)
        if (providerKey.isNullOrBlank()) {
            finish()
            return
        }
        title = intent.getStringExtra(EXTRA_SOURCE_NAME) ?: "Source settings"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(
                    android.R.id.content,
                    SourcePreferencesFragment().apply {
                        arguments = bundleOf(EXTRA_PROVIDER_KEY to providerKey)
                    },
                )
                .commit()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    companion object {
        const val EXTRA_PROVIDER_KEY = "providerKey"
        const val EXTRA_SOURCE_NAME = "sourceName"
    }
}

class SourcePreferencesFragment : PreferenceFragmentCompat() {
    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        // Placeholder screen; the real one is built once the extension runtime is ready.
        preferenceScreen = preferenceManager.createPreferenceScreen(requireContext())
        val providerKey =
            requireArguments().getString(SourcePreferencesActivity.EXTRA_PROVIDER_KEY).orEmpty()
        val runtime = AniyomiExtensionRuntime.get(requireContext())
        lifecycleScope.launch {
            val screen = runCatching {
                runtime.buildPreferenceScreen(preferenceManager, requireContext(), providerKey)
            }.getOrNull()
            if (screen != null) {
                preferenceScreen = screen
            } else {
                activity?.finish()
            }
        }
    }
}
