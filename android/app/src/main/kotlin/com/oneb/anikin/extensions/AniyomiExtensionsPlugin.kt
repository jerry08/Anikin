package com.oneb.anikin.extensions

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class AniyomiExtensionsPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    private val runtime = AniyomiExtensionRuntime.get(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(runtime.isSupported())
            "getRepos" -> result.success(runtime.getRepos())
            "addRepo" -> runCatchingResult(result) { runtime.addRepo(call.requiredString("url")) }
            "removeRepo" -> runCatchingResult(result) { runtime.removeRepo(call.requiredString("url")) }
            "getNsfwAllowed" -> result.success(runtime.isNsfwAllowed())
            "setNsfwAllowed" -> runCatchingResult(result) {
                runtime.setNsfwAllowed(call.argument<Boolean>("allowed") ?: true)
                true
            }
            "getAnimeProviders" -> launchResult(result) { runtime.getAnimeProviders() }
            "getMangaProviders" -> launchResult(result) { runtime.getMangaProviders() }
            "getAvailableExtensions" -> launchResult(result) { runtime.listAvailableExtensions() }
            "getInstalledExtensions" -> launchResult(result) { runtime.listInstalledExtensions() }
            "refreshAvailableExtensions" -> launchResult(result) { runtime.refreshAvailableExtensions() }
            "installExtension" -> launchResult(result) { runtime.installExtension(call.requiredString("pkgName")) }
            "updateExtension" -> launchResult(result) { runtime.updateExtension(call.requiredString("pkgName")) }
            "uninstallExtension" -> launchResult(result) { runtime.uninstallExtension(call.requiredString("pkgName")) }
            "getFilters" -> launchResult(result) {
                runtime.getFilters(call.requiredString("providerKey"))
            }
            "openSourcePreferences" -> runCatchingResult(result) {
                val intent = Intent(context, SourcePreferencesActivity::class.java).apply {
                    putExtra(SourcePreferencesActivity.EXTRA_PROVIDER_KEY, call.requiredString("providerKey"))
                    putExtra(SourcePreferencesActivity.EXTRA_SOURCE_NAME, call.argument<String>("sourceName"))
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            }
            "browseAnime" -> launchResult(result) {
                runtime.browseAnime(
                    call.requiredString("providerKey"),
                    call.page(),
                    call.kind(),
                )
            }
            "searchAnime" -> launchResult(result) {
                runtime.searchAnime(
                    call.requiredString("providerKey"),
                    call.requiredString("query"),
                    call.page(),
                    call.filterStates(),
                )
            }
            "getEpisodes" -> launchResult(result) {
                runtime.getEpisodes(call.requiredString("providerKey"), call.requiredString("animeId"))
            }
            "getVideoServers" -> launchResult(result) {
                runtime.getVideoServers(call.requiredString("providerKey"), call.requiredString("episodeId"))
            }
            "getVideos" -> launchResult(result) {
                runtime.getVideos(call.requiredString("providerKey"), call.requiredString("query"))
            }
            "browseManga" -> launchResult(result) {
                runtime.browseManga(
                    call.requiredString("providerKey"),
                    call.page(),
                    call.kind(),
                )
            }
            "searchManga" -> launchResult(result) {
                runtime.searchManga(
                    call.requiredString("providerKey"),
                    call.requiredString("query"),
                    call.page(),
                    call.filterStates(),
                )
            }
            "getMangaInfo" -> launchResult(result) {
                runtime.getMangaInfo(call.requiredString("providerKey"), call.requiredString("mangaId"))
            }
            "getChapterPages" -> launchResult(result) {
                runtime.getChapterPages(call.requiredString("providerKey"), call.requiredString("chapterId"))
            }
            else -> result.notImplemented()
        }
    }

    private fun <T> launchResult(result: MethodChannel.Result, block: suspend () -> T) {
        scope.launch {
            try {
                result.success(block())
            } catch (error: Throwable) {
                result.aniyomiError(error)
            }
        }
    }

    private fun <T> runCatchingResult(result: MethodChannel.Result, block: () -> T) {
        try {
            result.success(block())
        } catch (error: Throwable) {
            result.aniyomiError(error)
        }
    }

    private fun MethodChannel.Result.aniyomiError(error: Throwable) {
        Log.e(TAG, "Aniyomi extension call failed", error)
        error("ANIYOMI_EXTENSION_ERROR", error.message, error.stackTraceToString())
    }

    private fun MethodCall.requiredString(name: String): String {
        return argument<String>(name)?.takeIf { it.isNotBlank() }
            ?: error("Missing argument: $name")
    }

    private fun MethodCall.page(): Int = (argument<Number>("page") ?: 1).toInt().coerceAtLeast(1)

    private fun MethodCall.kind(): String =
        argument<String>("kind") ?: AniyomiExtensionRuntime.KIND_POPULAR

    @Suppress("UNCHECKED_CAST")
    private fun MethodCall.filterStates(): List<Map<String, Any?>>? {
        val raw = argument<List<Any?>>("filters") ?: return null
        return raw.filterIsInstance<Map<Any?, Any?>>().map { item ->
            item.entries.associate { (key, value) -> key.toString() to value }
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.oneb.anikin/aniyomi_extensions"
        private const val TAG = "AniyomiExtensions"

        fun registerWith(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(
                AniyomiExtensionsPlugin(context),
            )
        }
    }
}
