package com.oneb.anikin.extensions

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class AniyomiExtensionsPlugin(context: Context) : MethodChannel.MethodCallHandler {
    private val runtime = AniyomiExtensionRuntime.get(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(runtime.isSupported())
            "getRepos" -> result.success(runtime.getRepos())
            "addRepo" -> runCatchingResult(result) { runtime.addRepo(call.requiredString("url")) }
            "removeRepo" -> runCatchingResult(result) { runtime.removeRepo(call.requiredString("url")) }
            "getAnimeProviders" -> result.success(runtime.getAnimeProviders())
            "getMangaProviders" -> result.success(runtime.getMangaProviders())
            "getAvailableExtensions" -> result.success(runtime.listAvailableExtensions())
            "getInstalledExtensions" -> result.success(runtime.listInstalledExtensions())
            "refreshAvailableExtensions" -> launchResult(result) { runtime.refreshAvailableExtensions() }
            "installExtension" -> launchResult(result) { runtime.installExtension(call.requiredString("pkgName")) }
            "updateExtension" -> launchResult(result) { runtime.updateExtension(call.requiredString("pkgName")) }
            "uninstallExtension" -> launchResult(result) { runtime.uninstallExtension(call.requiredString("pkgName")) }
            "browseAnime" -> launchResult(result) {
                runtime.browseAnime(call.requiredString("providerKey"))
            }
            "searchAnime" -> launchResult(result) {
                runtime.searchAnime(call.requiredString("providerKey"), call.requiredString("query"))
            }
            "getEpisodes" -> launchResult(result) {
                runtime.getEpisodes(call.requiredString("providerKey"), call.requiredString("animeId"))
            }
            "getVideoServers" -> result.success(
                runtime.getVideoServers(call.requiredString("providerKey"), call.requiredString("episodeId")),
            )
            "getVideos" -> launchResult(result) {
                runtime.getVideos(call.requiredString("providerKey"), call.requiredString("query"))
            }
            "browseManga" -> launchResult(result) {
                runtime.browseManga(call.requiredString("providerKey"))
            }
            "searchManga" -> launchResult(result) {
                runtime.searchManga(call.requiredString("providerKey"), call.requiredString("query"))
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