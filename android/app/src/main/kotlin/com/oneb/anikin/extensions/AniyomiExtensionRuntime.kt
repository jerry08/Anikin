@file:Suppress("DEPRECATION")

package com.oneb.anikin.extensions

import android.annotation.SuppressLint
import android.app.Application
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.preference.DialogPreference
import androidx.preference.PreferenceManager
import androidx.preference.PreferenceScreen
import androidx.preference.forEach
import eu.kanade.tachiyomi.animesource.AnimeCatalogueSource
import eu.kanade.tachiyomi.animesource.AnimeSource
import eu.kanade.tachiyomi.animesource.AnimeSourceFactory
import eu.kanade.tachiyomi.animesource.ConfigurableAnimeSource
import eu.kanade.tachiyomi.animesource.model.AnimeFilter
import eu.kanade.tachiyomi.animesource.model.AnimeFilterList
import eu.kanade.tachiyomi.animesource.model.Hoster
import eu.kanade.tachiyomi.animesource.model.SAnime
import eu.kanade.tachiyomi.animesource.model.SEpisode
import eu.kanade.tachiyomi.animesource.model.Video
import eu.kanade.tachiyomi.animesource.online.AnimeHttpSource
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.source.CatalogueSource as MangaCatalogueSource
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.Source as MangaSource
import eu.kanade.tachiyomi.source.SourceFactory as MangaSourceFactory
import eu.kanade.tachiyomi.source.model.Filter as MangaFilter
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.online.HttpSource as MangaHttpSource
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import okhttp3.Headers
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.FullTypeReference
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

class AniyomiExtensionRuntime private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences("aniyomi_extensions", Context.MODE_PRIVATE)
    private val extensionDir = File(appContext.filesDir, "aniyomi_anime_exts")
    private val installedExtensions = ConcurrentHashMap<String, LoadedExtensionInfo>()
    private val failedExtensions = ConcurrentHashMap<String, FailedExtensionInfo>()
    private val animeSources = ConcurrentHashMap<Long, AnimeSource>()
    private val mangaSources = ConcurrentHashMap<Long, MangaSource>()

    @Volatile
    private var availableExtensions: List<AvailableExtensionInfo> = emptyList()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val ready = CompletableDeferred<Unit>()

    private val client get() = NetworkHelper.get().client

    init {
        // Loading extensions scans installed packages and instantiates source classes; keep
        // it off the main thread so app startup is not blocked.
        scope.launch {
            try {
                NetworkHelper.initialize(appContext)
                initializeHostDependencies()
                extensionDir.mkdirs()
                loadPersistedAvailableExtensions()
                reloadInstalledExtensions()
            } finally {
                ready.complete(Unit)
            }
        }
    }

    suspend fun awaitReady() = ready.await()

    fun isSupported(): Boolean = true

    fun isNsfwAllowed(): Boolean = prefs.getBoolean(KEY_SHOW_NSFW, true)

    fun setNsfwAllowed(allowed: Boolean) {
        prefs.edit().putBoolean(KEY_SHOW_NSFW, allowed).apply()
    }

    fun getRepos(): List<String> = prefs.getStringSet(KEY_REPOS, emptySet()).orEmpty().sorted()

    fun addRepo(input: String): List<String> {
        val repo = normalizeRepo(input)
        val repos = getRepos().toMutableSet()
        repos += repo
        prefs.edit().putStringSet(KEY_REPOS, repos).apply()
        return getRepos()
    }

    fun removeRepo(input: String): List<String> {
        val repo = normalizeRepo(input)
        val repos = getRepos().toMutableSet()
        repos -= repo
        prefs.edit().putStringSet(KEY_REPOS, repos).apply()
        availableExtensions = availableExtensions.filterNot { it.repoUrl == repo }
        persistAvailableExtensions()
        return getRepos()
    }

    suspend fun getAnimeProviders(): List<Map<String, Any?>> {
        awaitReady()
        val nsfwAllowed = isNsfwAllowed()
        return installedExtensions.values
            .filter { nsfwAllowed || !it.isNsfw }
            .flatMap { extension ->
                extension.sources.filterIsInstance<AnimeCatalogueSource>().map { source -> extension to source }
            }
            .sortedWith(compareBy({ it.second.lang }, { it.second.name.lowercase(Locale.ROOT) }))
            .map { (extension, source) ->
                mapOf(
                    "key" to providerKeyForAnimeSource(source.id),
                    "name" to source.name,
                    "language" to source.lang,
                    "type" to 0,
                    "supportsLatest" to source.supportsLatest,
                    "isNsfw" to extension.isNsfw,
                    "isConfigurable" to (source is ConfigurableAnimeSource),
                )
            }
    }

    suspend fun getMangaProviders(): List<Map<String, Any?>> {
        awaitReady()
        val nsfwAllowed = isNsfwAllowed()
        return installedExtensions.values
            .filter { nsfwAllowed || !it.isNsfw }
            .flatMap { extension ->
                extension.sources.filterIsInstance<MangaCatalogueSource>().map { source -> extension to source }
            }
            .sortedWith(compareBy({ it.second.lang }, { it.second.name.lowercase(Locale.ROOT) }))
            .map { (extension, source) ->
                mapOf(
                    "key" to providerKeyForMangaSource(source.id),
                    "name" to source.name,
                    "language" to source.lang,
                    "type" to 1,
                    "supportsLatest" to source.supportsLatest,
                    "isNsfw" to extension.isNsfw,
                    "isConfigurable" to (source is ConfigurableSource),
                )
            }
    }

    suspend fun refreshAvailableExtensions(): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        awaitReady()
        val repos = getRepos()
        val results = repos.map { repo -> repo to runCatching { fetchRepo(repo) } }
        val failures = results.filter { it.second.isFailure }
        if (repos.isNotEmpty() && failures.size == repos.size) {
            val reason = failures.firstNotNullOfOrNull { it.second.exceptionOrNull()?.message }
            error("Failed to fetch extension repos${if (reason != null) ": $reason" else ""}")
        }
        availableExtensions = results
            .flatMap { it.second.getOrDefault(emptyList()) }
            .distinctBy { it.pkgName }
            .sortedWith(compareBy<AvailableExtensionInfo> { it.lang }.thenBy { it.name.lowercase(Locale.ROOT) })
        persistAvailableExtensions()
        listAvailableExtensionsInternal()
    }

    suspend fun listAvailableExtensions(): List<Map<String, Any?>> {
        awaitReady()
        return listAvailableExtensionsInternal()
    }

    private fun listAvailableExtensionsInternal(): List<Map<String, Any?>> {
        val nsfwAllowed = isNsfwAllowed()
        return availableExtensions
            .filter { nsfwAllowed || !it.isNsfw }
            .map { available ->
                available.toMap(
                    installed = installedExtensions[available.pkgName],
                    failed = failedExtensions[available.pkgName],
                )
            }
    }

    suspend fun listInstalledExtensions(): List<Map<String, Any?>> {
        awaitReady()
        val loaded = installedExtensions.values.map { installed ->
            installed.name to installed.toMap().toMutableMap().also { map ->
                val available = availableExtensions.firstOrNull { it.pkgName == installed.pkgName }
                if (available != null) {
                    map["hasUpdate"] = available.versionCode > installed.versionCode || available.libVersion > installed.libVersion
                    map["iconUrl"] = available.iconUrl
                }
            }
        }
        val failed = failedExtensions.values.map { extension ->
            extension.name to extension.toMap().toMutableMap().also { map ->
                val available = availableExtensions.firstOrNull { it.pkgName == extension.pkgName }
                if (available != null) {
                    map["hasUpdate"] =
                        available.versionCode > extension.versionCode || available.libVersion > extension.libVersion
                    map["iconUrl"] = available.iconUrl
                }
            }
        }
        return (loaded + failed)
            .sortedBy { it.first.lowercase(Locale.ROOT) }
            .map { it.second }
    }

    suspend fun installExtension(pkgName: String): Map<String, Any?> = withContext(Dispatchers.IO) {
        awaitReady()
        val available = availableExtensions.firstOrNull { it.pkgName == pkgName }
            ?: refreshAndFind(pkgName)
            ?: error("Extension not found in configured repos: $pkgName")
        val apkUrl = "${available.repoUrl.trimEnd('/')}/apk/${available.apkName}"
        val temp = File(appContext.cacheDir, "${available.pkgName}.apk")
        var installLocation = ExtensionInstallLocation.System
        try {
            client.newCall(Request.Builder().url(apkUrl).build()).execute().use { response ->
                if (!response.isSuccessful) error("Extension download failed: HTTP ${response.code}")
                val body = response.body ?: error("Extension download returned an empty body")
                temp.outputStream().use { output -> body.byteStream().copyTo(output) }
            }
            val extension = archivePackageInfo(temp) ?: error("Downloaded file is not a valid APK")
            validateInstallCandidate(extension)
            validateUpdateSafety(extension)
            try {
                installSystemExtensionFile(temp, extension)
                awaitSystemExtensionVisible(extension.packageName)
            } catch (systemError: Exception) {
                if (systemError is kotlinx.coroutines.CancellationException &&
                    systemError !is kotlinx.coroutines.TimeoutCancellationException
                ) {
                    throw systemError
                }
                // The system installer can fail when the user declines the prompt or the
                // OEM blocks session installs; fall back to loading the APK privately.
                installPrivateExtensionFile(temp)
                installLocation = ExtensionInstallLocation.Private
            }
        } finally {
            temp.delete()
        }
        reloadInstalledExtensions()
        val loadFailure = failedExtensions[pkgName]
        mapOf(
            "ok" to true,
            "installLocation" to installLocation.wireName,
            "loaded" to (loadFailure == null),
            "loadError" to loadFailure?.loadError,
        )
    }

    suspend fun updateExtension(pkgName: String): Map<String, Any?> = installExtension(pkgName)

    suspend fun uninstallExtension(pkgName: String): Map<String, Any?> {
        awaitReady()
        val privateFile = File(extensionDir, "$pkgName.$PRIVATE_EXTENSION_EXTENSION")
        if (installedPackageInfo(pkgName) != null) {
            uninstallSystemExtension(pkgName)
            privateFile.delete()
        } else {
            privateFile.delete()
        }
        reloadInstalledExtensions()
        return mapOf("ok" to true)
    }

    suspend fun getFilters(providerKey: String): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        awaitReady()
        when {
            isMangaProviderKey(providerKey) -> {
                val source = mangaSourceForProviderKey(providerKey) as? MangaCatalogueSource
                    ?: return@withContext emptyList()
                safeFilters(source).map { filter -> mangaFilterToMap(filter) }
            }
            else -> {
                val source = animeSourceForProviderKey(providerKey) as? AnimeCatalogueSource
                    ?: return@withContext emptyList()
                safeFilters(source).map { filter -> animeFilterToMap(filter) }
            }
        }
    }

    suspend fun browseAnime(providerKey: String, page: Int, kind: String): Map<String, Any?> = withContext(Dispatchers.IO) {
        awaitReady()
        val source = animeSourceForProviderKey(providerKey) as? AnimeCatalogueSource
            ?: return@withContext emptyPage()
        val result = if (kind == KIND_LATEST && source.supportsLatest) {
            source.getLatestUpdates(page)
        } else {
            source.getPopularAnime(page)
        }
        mapOf(
            "items" to result.animes.map { anime -> animeToMap(source, anime) },
            "hasNextPage" to result.hasNextPage,
        )
    }

    suspend fun searchAnime(
        providerKey: String,
        query: String,
        page: Int,
        filterStates: List<Map<String, Any?>>?,
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        awaitReady()
        val source = animeSourceForProviderKey(providerKey) as? AnimeCatalogueSource
            ?: return@withContext emptyPage()
        val filters = appliedAnimeFilters(source, filterStates)
        val result = source.getSearchAnime(page, query, filters)
        mapOf(
            "items" to result.animes.map { anime -> animeToMap(source, anime) },
            "hasNextPage" to result.hasNextPage,
        )
    }

    suspend fun getEpisodes(providerKey: String, animeId: String): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        awaitReady()
        val (sourceId, anime) = OpaqueIds.decodeAnime(animeId) ?: return@withContext emptyList()
        val source = animeSources[sourceId] ?: return@withContext emptyList()
        val details = runCatching { source.getAnimeDetails(anime) }.getOrDefault(anime)
        source.getEpisodeList(details).map { episode -> episodeToMap(sourceId, episode) }
    }

    suspend fun getVideoServers(providerKey: String, episodeId: String): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        awaitReady()
        val (sourceId, episode) = OpaqueIds.decodeEpisode(episodeId) ?: return@withContext emptyList()
        val source = animeSources[sourceId] ?: return@withContext emptyList()
        val hosters = fetchHosters(source, episode)
        if (hosters.isEmpty()) return@withContext emptyList()
        hosters.mapIndexed { index, hoster ->
            mapOf(
                "name" to hoster.hosterName.ifBlank { "Server ${index + 1}" },
                "embed" to mapOf(
                    "url" to OpaqueIds.hosterId(sourceId, episode, index, hoster.hosterName),
                    "headers" to emptyMap<String, String>(),
                ),
            )
        }
    }

    suspend fun getVideos(providerKey: String, query: String): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        awaitReady()
        val hosterRef = OpaqueIds.decodeHoster(query)
        if (hosterRef != null) {
            val source = animeSources[hosterRef.sourceId] ?: return@withContext emptyList()
            val hosters = fetchHosters(source, hosterRef.episode)
            val hoster = hosters.getOrNull(hosterRef.index)
                ?.takeIf { it.hosterName == hosterRef.name }
                ?: hosters.firstOrNull { it.hosterName == hosterRef.name }
                ?: hosters.getOrNull(hosterRef.index)
                ?: return@withContext emptyList()
            val videos = hoster.videoList
                ?: runCatching { source.getVideoList(hoster) }.getOrDefault(emptyList())
            return@withContext videos.mapNotNull { video ->
                videoToMap(source, video, hoster.hosterName.ifBlank { "Aniyomi" })
            }
        }
        val (sourceId, episode) = OpaqueIds.decodeEpisode(query) ?: return@withContext emptyList()
        val source = animeSources[sourceId] ?: return@withContext emptyList()
        val videos = loadVideos(source, episode)
        videos.mapNotNull { video -> videoToMap(source, video, "Aniyomi") }
    }

    suspend fun browseManga(providerKey: String, page: Int, kind: String): Map<String, Any?> = withContext(Dispatchers.IO) {
        awaitReady()
        val source = mangaSourceForProviderKey(providerKey) as? MangaCatalogueSource
            ?: return@withContext emptyPage()
        val result = if (kind == KIND_LATEST && source.supportsLatest) {
            source.getLatestUpdates(page)
        } else {
            source.getPopularManga(page)
        }
        mapOf(
            "items" to result.mangas.map { manga -> mangaToMap(source, manga) },
            "hasNextPage" to result.hasNextPage,
        )
    }

    suspend fun searchManga(
        providerKey: String,
        query: String,
        page: Int,
        filterStates: List<Map<String, Any?>>?,
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        awaitReady()
        val source = mangaSourceForProviderKey(providerKey) as? MangaCatalogueSource
            ?: return@withContext emptyPage()
        val filters = appliedMangaFilters(source, filterStates)
        val result = source.getSearchManga(page, query, filters)
        mapOf(
            "items" to result.mangas.map { manga -> mangaToMap(source, manga) },
            "hasNextPage" to result.hasNextPage,
        )
    }

    suspend fun getMangaInfo(providerKey: String, mangaId: String): Map<String, Any?> = withContext(Dispatchers.IO) {
        awaitReady()
        val (sourceId, manga) = OpaqueIds.decodeManga(mangaId) ?: return@withContext emptyMap()
        val source = mangaSources[sourceId] ?: return@withContext emptyMap()
        val details = runCatching { source.getMangaDetails(manga) }.getOrDefault(manga)
        val chapters = runCatching { source.getChapterList(details) }.getOrDefault(emptyList())
        mangaToMap(source, details) + mapOf("chapters" to chapters.map { chapter -> chapterToMap(sourceId, chapter) })
    }

    suspend fun getChapterPages(providerKey: String, chapterId: String): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        awaitReady()
        val (sourceId, chapter) = OpaqueIds.decodeChapter(chapterId) ?: return@withContext emptyList()
        val source = mangaSources[sourceId] ?: return@withContext emptyList()
        source.getPageList(chapter).mapNotNull { page -> pageToMap(source, page) }
    }

    /**
     * Builds the androidx preference screen a configurable source defines. Must be called on
     * the main thread (the preference framework requires it).
     */
    suspend fun buildPreferenceScreen(
        preferenceManager: PreferenceManager,
        context: Context,
        providerKey: String,
    ): PreferenceScreen? {
        awaitReady()
        val source: Any = animeSourceForProviderKey(providerKey)
            ?: mangaSourceForProviderKey(providerKey)
            ?: return null
        val sourceId = when (source) {
            is AnimeSource -> source.id
            is MangaSource -> source.id
            else -> return null
        }
        preferenceManager.preferenceDataStore = SharedPreferencesDataStore(
            appContext.getSharedPreferences("source_$sourceId", Context.MODE_PRIVATE),
        )
        val screen = preferenceManager.createPreferenceScreen(context)
        when (source) {
            is ConfigurableAnimeSource -> source.setupPreferenceScreen(screen)
            is ConfigurableSource -> source.setupPreferenceScreen(screen)
            else -> return null
        }
        screen.forEach { pref ->
            pref.isIconSpaceReserved = false
            if (pref is DialogPreference) {
                pref.dialogTitle = pref.title
            }
        }
        return screen
    }

    fun sourceDisplayName(providerKey: String): String? {
        val source: Any? = animeSourceForProviderKey(providerKey) ?: mangaSourceForProviderKey(providerKey)
        return when (source) {
            is AnimeSource -> source.name
            is MangaSource -> source.name
            else -> null
        }
    }

    @OptIn(ExperimentalSerializationApi::class)
    private fun initializeHostDependencies() {
        (appContext as? Application)?.let { application ->
            Injekt.addSingleton(typeRef<Application>(), application)
        }
        Injekt.addSingleton(typeRef<Context>(), appContext)
        Injekt.addSingletonFactory(typeRef<NetworkHelper>()) { NetworkHelper.get() }
        Injekt.addSingletonFactory(typeRef<okhttp3.OkHttpClient>()) { NetworkHelper.get().client }
        Injekt.addSingletonFactory(typeRef<Json>()) {
            Json {
                ignoreUnknownKeys = true
                explicitNulls = false
            }
        }
    }

    private suspend fun refreshAndFind(pkgName: String): AvailableExtensionInfo? {
        refreshAvailableExtensions()
        return availableExtensions.firstOrNull { it.pkgName == pkgName }
    }

    private fun fetchRepo(repoUrl: String): List<AvailableExtensionInfo> {
        val primary = "${repoUrl.trimEnd('/')}/index.min.json"
        val primaryResult = runCatching { fetchRepoIndex(primary, repoUrl) }
        if (primaryResult.isSuccess) return primaryResult.getOrThrow()
        val fallback = jsDelivrFallbackUrl(repoUrl)
        if (fallback != null) {
            val fallbackResult = runCatching { fetchRepoIndex("$fallback/index.min.json", repoUrl) }
            if (fallbackResult.isSuccess) return fallbackResult.getOrThrow()
        }
        throw primaryResult.exceptionOrNull() ?: IllegalStateException("Failed to fetch $repoUrl")
    }

    private fun fetchRepoIndex(indexUrl: String, repoUrl: String): List<AvailableExtensionInfo> {
        return client.newCall(Request.Builder().url(indexUrl).build()).execute().use { response ->
            if (!response.isSuccessful) error("HTTP ${response.code} for $indexUrl")
            val body = response.body ?: error("Empty response for $indexUrl")
            parseAvailableExtensions(JSONArray(body.string()), repoUrl)
        }
    }

    /**
     * raw.githubusercontent.com is blocked in some regions; jsDelivr mirrors the same
     * repository content.
     */
    private fun jsDelivrFallbackUrl(repoUrl: String): String? {
        val prefix = "https://raw.githubusercontent.com/"
        if (!repoUrl.startsWith(prefix)) return null
        val parts = repoUrl.removePrefix(prefix).split("/")
        if (parts.size < 3) return null
        val user = parts[0]
        val repo = parts[1]
        val branch = parts[2]
        val rest = parts.drop(3).joinToString("/")
        return "https://cdn.jsdelivr.net/gh/$user/$repo@$branch" + if (rest.isEmpty()) "" else "/$rest"
    }

    private fun parseAvailableExtensions(json: JSONArray, repoUrl: String): List<AvailableExtensionInfo> {
        return buildList {
            for (index in 0 until json.length()) {
                val item = json.optJSONObject(index) ?: continue
                val versionName = item.optString("version")
                val mediaType = inferAvailableMediaType(item.optString("name"), item.optString("pkg"), item.optString("apk"))
                val libVersion = extractLibVersion(versionName) ?: continue
                if (!isSupportedLibVersion(mediaType, libVersion)) continue
                val pkgName = item.optString("pkg")
                val sourcesJson = item.optJSONArray("sources")
                val sourceItems = buildList {
                    if (sourcesJson != null) {
                        for (sourceIndex in 0 until sourcesJson.length()) {
                            val source = sourcesJson.optJSONObject(sourceIndex) ?: continue
                            add(
                                AvailableSourceInfo(
                                    id = source.optLong("id"),
                                    lang = source.optString("lang"),
                                    name = source.optString("name"),
                                    baseUrl = source.optString("baseUrl"),
                                    mediaType = mediaType,
                                ),
                            )
                        }
                    }
                }
                add(
                    AvailableExtensionInfo(
                        name = item.optString("name").substringAfter("Aniyomi: "),
                        pkgName = pkgName,
                        versionName = versionName,
                        versionCode = item.optLong("code"),
                        libVersion = libVersion,
                        lang = item.optString("lang"),
                        isNsfw = item.optInt("nsfw") == 1,
                        mediaType = mediaType,
                        apkName = item.optString("apk", "$pkgName.apk"),
                        repoUrl = repoUrl,
                        iconUrl = "$repoUrl/icon/$pkgName.png",
                        sources = sourceItems,
                    ),
                )
            }
        }
    }

    private fun persistAvailableExtensions() {
        val json = JSONArray()
        availableExtensions.forEach { available -> json.put(available.toJson()) }
        prefs.edit().putString(KEY_AVAILABLE_CACHE, json.toString()).apply()
    }

    private fun loadPersistedAvailableExtensions() {
        val raw = prefs.getString(KEY_AVAILABLE_CACHE, null) ?: return
        val loaded = runCatching {
            val json = JSONArray(raw)
            buildList {
                for (index in 0 until json.length()) {
                    val item = json.optJSONObject(index) ?: continue
                    AvailableExtensionInfo.fromJson(item)?.let(::add)
                }
            }
        }.getOrDefault(emptyList())
        if (loaded.isNotEmpty() && availableExtensions.isEmpty()) {
            availableExtensions = loaded
        }
    }

    private fun validateInstallCandidate(extension: PackageInfo) {
        if (!isPackageAnExtension(extension)) error("APK is not a supported Aniyomi/Tachiyomi extension")
        val mediaType = packageMediaType(extension) ?: error("APK is not a supported Aniyomi/Tachiyomi extension")
        val versionName = extension.versionName ?: error("Extension is missing a version")
        val libVersion = extractLibVersion(versionName) ?: error("Extension has an unsupported lib version")
        if (!isSupportedLibVersion(mediaType, libVersion)) error("Extension lib version is not supported: $libVersion")
    }

    private fun validateUpdateSafety(extension: PackageInfo) {
        val current = selectedPackageCandidate(extension.packageName)?.pkgInfo ?: return
        if (extension.versionCodeCompat() < current.versionCodeCompat()) error("Downgrading extensions is not allowed")
        val newSignatures = getSignatures(extension)
        val oldSignatures = getSignatures(current)
        if (newSignatures.isNotEmpty() && oldSignatures.isNotEmpty() && !newSignatures.containsAll(oldSignatures)) {
            error("Extension signature does not match the installed version")
        }
    }

    private suspend fun installSystemExtensionFile(file: File, extension: PackageInfo) {
        val installer = appContext.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(extension.packageName)
        }
        val sessionId = installer.createSession(params)
        var session: PackageInstaller.Session? = null
        try {
            val activeSession = installer.openSession(sessionId)
            session = activeSession
            activeSession.openWrite("base.apk", 0, file.length()).use { output ->
                file.inputStream().use { input -> input.copyTo(output) }
                activeSession.fsync(output)
            }
            awaitPackageInstallerResult("$PACKAGE_INSTALL_ACTION.$sessionId") { sender ->
                activeSession.commit(sender)
                activeSession.close()
                session = null
            }
        } catch (error: Throwable) {
            runCatching { installer.abandonSession(sessionId) }
            throw error
        } finally {
            session?.close()
        }
    }

    private suspend fun awaitSystemExtensionVisible(pkgName: String) {
        repeat(PACKAGE_VISIBILITY_RETRIES) {
            if (installedPackageInfo(pkgName) != null) return
            delay(PACKAGE_VISIBILITY_RETRY_DELAY_MS)
        }
        error("Installed extension is not visible to Anikin: $pkgName")
    }

    private suspend fun uninstallSystemExtension(pkgName: String) {
        awaitPackageInstallerResult("$PACKAGE_UNINSTALL_ACTION.${pkgName.hashCode()}") { sender ->
            appContext.packageManager.packageInstaller.uninstall(pkgName, sender)
        }
    }

    private suspend fun awaitPackageInstallerResult(action: String, start: (android.content.IntentSender) -> Unit) {
        val deferred = CompletableDeferred<Unit>()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
                when (status) {
                    PackageInstaller.STATUS_SUCCESS -> deferred.complete(Unit)
                    PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                        val confirmation = intent.pendingUserActionIntent()
                        if (confirmation != null) {
                            confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            appContext.startActivity(confirmation)
                        } else if (!deferred.isCompleted) {
                            deferred.completeExceptionally(IllegalStateException("Package installer requires confirmation but did not provide an intent"))
                        }
                    }
                    else -> {
                        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                            ?: "Package installer failed with status $status"
                        if (!deferred.isCompleted) deferred.completeExceptionally(IllegalStateException(message))
                    }
                }
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            appContext.registerReceiver(receiver, filter)
        }
        try {
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            val pendingIntent = PendingIntent.getBroadcast(
                appContext,
                action.hashCode(),
                Intent(action).setPackage(appContext.packageName),
                flags,
            )
            start(pendingIntent.intentSender)
            withTimeout(PACKAGE_INSTALL_TIMEOUT_MS) { deferred.await() }
        } finally {
            runCatching { appContext.unregisterReceiver(receiver) }
        }
    }

    @Suppress("DEPRECATION")
    private fun Intent.pendingUserActionIntent(): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            getParcelableExtra(Intent.EXTRA_INTENT)
        }
    }

    private fun installPrivateExtensionFile(file: File) {
        val extension = archivePackageInfo(file) ?: error("Downloaded file is not a valid APK")
        validateInstallCandidate(extension)
        val target = File(extensionDir, "${extension.packageName}.$PRIVATE_EXTENSION_EXTENSION")
        val current = privatePackageInfo(extension.packageName)
        if (current != null) {
            if (extension.versionCodeCompat() < current.versionCodeCompat()) error("Downgrading extensions is not allowed")
            val newSignatures = getSignatures(extension)
            val oldSignatures = getSignatures(current)
            if (newSignatures.isEmpty() || oldSignatures.isEmpty() || !newSignatures.containsAll(oldSignatures)) {
                error("Extension signature does not match the installed version")
            }
        }
        extensionDir.mkdirs()
        target.delete()
        file.copyTo(target, overwrite = true)
        target.setReadOnly()
    }

    @Synchronized
    private fun reloadInstalledExtensions() {
        installedExtensions.clear()
        failedExtensions.clear()
        animeSources.clear()
        mangaSources.clear()
        extensionPackageCandidates().forEach { candidate ->
            when (val result = loadExtension(candidate)) {
                is LoadResult.Success -> {
                    installedExtensions[result.extension.pkgName] = result.extension
                    result.extension.sources.forEach { source ->
                        when (source) {
                            is AnimeSource -> animeSources[source.id] = source
                            is MangaSource -> mangaSources[source.id] = source
                        }
                    }
                }
                is LoadResult.Error -> {
                    failedExtensionInfo(candidate, result)?.let { failure ->
                        failedExtensions[failure.pkgName] = failure
                    }
                    Log.e(
                        TAG,
                        "Failed to load extension ${candidate.pkgInfo.packageName}: ${result.message}",
                        result.cause,
                    )
                }
            }
        }
    }

    private fun loadExtension(candidate: ExtensionPackageCandidate): LoadResult {
        val pkgInfo = candidate.pkgInfo
        if (!isPackageAnExtension(pkgInfo)) return LoadResult.Error("Package is not a supported extension")
        val appInfo = pkgInfo.applicationInfo ?: return LoadResult.Error("Extension has no application information")
        appInfo.fixBasePaths(candidate.apkPath)
        val mediaType = packageMediaType(pkgInfo) ?: return LoadResult.Error("Extension media type is missing")
        val pkgName = pkgInfo.packageName
        val extensionName = packageLabel(appInfo).substringAfter("Aniyomi: ")
            .substringAfter("Tachiyomi: ")
        val versionName = pkgInfo.versionName ?: return LoadResult.Error("Extension version is missing")
        val libVersion = extractLibVersion(versionName)
            ?: return LoadResult.Error("Extension lib version is invalid: $versionName")
        if (!isSupportedLibVersion(mediaType, libVersion)) {
            return LoadResult.Error("Extension lib version is not supported: $libVersion")
        }
        val signatures = getSignatures(pkgInfo)
        val signatureHash = signatures.lastOrNull().orEmpty()
        val sourceClassNames = appInfo.metaData?.getString(metadataSourceClass(mediaType))?.split(';').orEmpty()
        if (sourceClassNames.isEmpty()) return LoadResult.Error("Extension declares no source classes")
        val classLoader = ChildFirstPathClassLoader(candidate.apkPath, appContext.classLoader)
        val sourceLoadErrors = mutableListOf<Pair<String, Throwable>>()
        val unsupportedSourceClasses = mutableListOf<String>()
        val loadedSources = sourceClassNames.flatMap { rawClassName ->
            val className = rawClassName.trim().let { if (it.startsWith('.')) pkgName + it else it }
            runCatching<List<Any>> {
                when (val instance = Class.forName(className, false, classLoader).getDeclaredConstructor().newInstance()) {
                    is AnimeSource -> listOf(instance)
                    is AnimeSourceFactory -> instance.createSources()
                    is MangaSource -> listOf(instance)
                    is MangaSourceFactory -> instance.createSources()
                    else -> {
                        unsupportedSourceClasses += className
                        emptyList()
                    }
                }
            }.getOrElse { error ->
                sourceLoadErrors += className to error
                emptyList()
            }
        }
        if (loadedSources.isEmpty()) {
            val firstFailure = sourceLoadErrors.firstOrNull()
            val message = when {
                firstFailure != null -> {
                    val (className, error) = firstFailure
                    "Could not load $className: ${error.describeForExtensionLoad()}"
                }
                unsupportedSourceClasses.isNotEmpty() ->
                    "Source class does not implement a supported source API: ${unsupportedSourceClasses.first()}"
                else -> "Extension did not create any sources"
            }
            return LoadResult.Error(message, firstFailure?.second)
        }
        val langs = loadedSources.mapNotNull { source ->
            when (source) {
                is AnimeCatalogueSource -> source.lang
                is MangaCatalogueSource -> source.lang
                else -> null
            }
        }.toSet()
        val lang = when (langs.size) {
            0 -> ""
            1 -> langs.first()
            else -> "all"
        }
        return LoadResult.Success(
            LoadedExtensionInfo(
                name = extensionName,
                pkgName = pkgName,
                versionName = versionName,
                versionCode = pkgInfo.versionCodeCompat(),
                libVersion = libVersion,
                lang = lang,
                isNsfw = appInfo.metaData?.getInt(metadataNsfw(mediaType), 0) == 1,
                mediaType = mediaType,
                signatureHash = signatureHash,
                installLocation = if (candidate.isPrivate) ExtensionInstallLocation.Private else ExtensionInstallLocation.System,
                sources = loadedSources,
            ),
        )
    }

    private fun failedExtensionInfo(
        candidate: ExtensionPackageCandidate,
        error: LoadResult.Error,
    ): FailedExtensionInfo? {
        val pkgInfo = candidate.pkgInfo
        val appInfo = pkgInfo.applicationInfo ?: return null
        val mediaType = packageMediaType(pkgInfo) ?: return null
        val pkgName = pkgInfo.packageName
        val versionName = pkgInfo.versionName.orEmpty()
        return FailedExtensionInfo(
            name = packageLabel(appInfo).substringAfter("Aniyomi: ").substringAfter("Tachiyomi: "),
            pkgName = pkgName,
            versionName = versionName,
            versionCode = pkgInfo.versionCodeCompat(),
            libVersion = extractLibVersion(versionName) ?: 0.0,
            lang = availableExtensions.firstOrNull { it.pkgName == pkgName }?.lang.orEmpty(),
            isNsfw = appInfo.metaData?.getInt(metadataNsfw(mediaType), 0) == 1,
            mediaType = mediaType,
            signatureHash = getSignatures(pkgInfo).lastOrNull().orEmpty(),
            installLocation = if (candidate.isPrivate) {
                ExtensionInstallLocation.Private
            } else {
                ExtensionInstallLocation.System
            },
            loadError = error.message,
        )
    }

    private fun extensionPackageCandidates(): List<ExtensionPackageCandidate> {
        val candidates = linkedMapOf<String, ExtensionPackageCandidate>()
        (systemExtensionCandidates() + privateExtensionCandidates()).forEach { candidate ->
            val existing = candidates[candidate.pkgInfo.packageName]
            if (existing == null || shouldPrefer(candidate, existing)) {
                candidates[candidate.pkgInfo.packageName] = candidate
            }
        }
        return candidates.values.toList()
    }

    @SuppressLint("QueryPermissionsNeeded")
    private fun systemExtensionCandidates(): List<ExtensionPackageCandidate> {
        return appContext.packageManager.getInstalledPackages(PACKAGE_FLAGS)
            .filter { isPackageAnExtension(it) }
            .mapNotNull { pkgInfo ->
                val appInfo = pkgInfo.applicationInfo ?: return@mapNotNull null
                ExtensionPackageCandidate(pkgInfo, appInfo.sourceDir, isPrivate = false)
            }
    }

    private fun privateExtensionCandidates(): List<ExtensionPackageCandidate> {
        return extensionDir.listFiles { file -> file.isFile && file.extension == PRIVATE_EXTENSION_EXTENSION }
            ?.mapNotNull { file ->
                if (file.canWrite()) file.setReadOnly()
                val pkgInfo = archivePackageInfo(file) ?: return@mapNotNull null
                if (!isPackageAnExtension(pkgInfo)) return@mapNotNull null
                ExtensionPackageCandidate(pkgInfo, file.absolutePath, isPrivate = true)
            }
            .orEmpty()
    }

    private fun selectedPackageCandidate(pkgName: String): ExtensionPackageCandidate? {
        return extensionPackageCandidates().firstOrNull { it.pkgInfo.packageName == pkgName }
    }

    private fun shouldPrefer(candidate: ExtensionPackageCandidate, existing: ExtensionPackageCandidate): Boolean {
        val candidateVersion = candidate.pkgInfo.versionCodeCompat()
        val existingVersion = existing.pkgInfo.versionCodeCompat()
        return candidateVersion > existingVersion ||
            (candidateVersion == existingVersion && !candidate.isPrivate && existing.isPrivate)
    }

    private suspend fun fetchHosters(source: AnimeSource, episode: SEpisode): List<Hoster> {
        val hosters = runCatching { source.getHosterList(episode) }.getOrDefault(emptyList())
        val real = hosters.filterNot { it.hosterName == Hoster.NO_HOSTER_LIST }
        if (real.isEmpty()) return emptyList()
        return if (source is AnimeHttpSource) with(source) { real.sortHosters() } else real
    }

    private suspend fun loadVideos(source: AnimeSource, episode: SEpisode): List<Video> {
        val hosters = runCatching { source.getHosterList(episode) }.getOrDefault(emptyList())
        if (hosters.isNotEmpty()) {
            val sorted = if (source is AnimeHttpSource) with(source) { hosters.sortHosters() } else hosters
            return sorted.flatMap { hoster ->
                hoster.videoList ?: runCatching { source.getVideoList(hoster) }.getOrDefault(emptyList())
            }
        }
        return runCatching { source.getVideoList(episode) }.getOrDefault(emptyList())
    }

    private suspend fun videoToMap(source: AnimeSource, video: Video, serverName: String): Map<String, Any?>? {
        val resolved = if (source is AnimeHttpSource) runCatching { source.resolveVideo(video) }.getOrNull() ?: video else video
        var videoUrl = resolved.videoUrl.takeIf { it.isNotBlank() && it != "null" }
        if (videoUrl == null && source is AnimeHttpSource) {
            videoUrl = runCatching { source.getVideoUrl(resolved) }.getOrNull()
        }
        if (videoUrl.isNullOrBlank() || videoUrl == "null") return null
        val headers = resolved.headers?.toSingleValueMap().orEmpty()
        return mapOf(
            "title" to resolved.videoTitle.ifBlank { resolved.quality.ifBlank { resolved.resolution?.let { "${it}p" } } },
            "resolution" to resolved.resolution?.let { "${it}p" },
            "videoUrl" to videoUrl,
            "format" to if (videoUrl.contains(".m3u8", ignoreCase = true)) "hls" else "container",
            "headers" to headers,
            "subtitles" to resolved.subtitleTracks.map { track ->
                mapOf(
                    "url" to track.url,
                    "language" to track.lang,
                    "type" to "vtt",
                    "headers" to headers,
                )
            },
            "videoServer" to mapOf(
                "name" to serverName,
                "embed" to mapOf("url" to (resolved.url.ifBlank { videoUrl }), "headers" to headers),
            ),
        )
    }

    private fun animeToMap(source: AnimeSource, anime: SAnime): Map<String, Any?> = mapOf(
        "id" to OpaqueIds.animeId(source.id, anime),
        "title" to anime.title,
        "image" to anime.thumbnail_url,
        "headers" to sourceHeaders(source),
        "summary" to anime.description,
        "status" to statusName(anime.status),
        "genres" to anime.getGenres().orEmpty(),
        "type" to null,
        "released" to null,
        "site" to 0,
    )

    private fun episodeToMap(sourceId: Long, episode: SEpisode): Map<String, Any?> = mapOf(
        "id" to OpaqueIds.episodeId(sourceId, episode),
        "name" to episode.name,
        "number" to (episode.episode_number.takeIf { it >= 0f }?.toDouble() ?: 0.0),
        "description" to episode.summary,
        "image" to episode.preview_url,
        "link" to episode.url,
    )

    private fun mangaToMap(source: MangaSource, manga: SManga): Map<String, Any?> = mapOf(
        "id" to OpaqueIds.mangaId(source.id, manga),
        "title" to manga.title,
        "image" to manga.thumbnail_url,
        "description" to manga.description,
        "link" to manga.url,
        "headers" to sourceHeaders(source),
        "genres" to manga.getGenres().orEmpty(),
        "status" to mangaStatusName(manga.status),
        "authors" to listOfNotNull(manga.author).filter { it.isNotBlank() },
        "altTitles" to listOfNotNull(manga.artist).filter { it.isNotBlank() },
    )

    private fun chapterToMap(sourceId: Long, chapter: SChapter): Map<String, Any?> = mapOf(
        "id" to OpaqueIds.chapterId(sourceId, chapter),
        "title" to chapter.name,
        "number" to (chapter.chapter_number.takeIf { it >= 0f }?.toDouble() ?: 0.0),
        "views" to chapter.scanlator,
    )

    private suspend fun pageToMap(source: MangaSource, page: Page): Map<String, Any?>? {
        val image = page.imageUrl ?: if (source is MangaHttpSource) runCatching { source.getImageUrl(page) }.getOrNull() else null
        if (image.isNullOrBlank()) return null
        return mapOf(
            "image" to image,
            "page" to page.index,
            "title" to null,
            "headers" to sourceHeaders(source),
        )
    }

    private fun sourceHeaders(source: Any?): Map<String, String> {
        val headers: Headers? = when (source) {
            is AnimeHttpSource -> runCatching { source.headers }.getOrNull()
            is MangaHttpSource -> runCatching { source.headers }.getOrNull()
            else -> null
        }
        return headers?.toSingleValueMap().orEmpty()
    }

    private fun Headers.toSingleValueMap(): Map<String, String> =
        toMultimap().mapValues { it.value.firstOrNull().orEmpty() }

    private fun animeSourceForProviderKey(providerKey: String): AnimeSource? {
        val sourceId = providerKey.removePrefix(ANIME_PROVIDER_KEY_PREFIX).toLongOrNull() ?: return null
        return animeSources[sourceId]
    }

    private fun mangaSourceForProviderKey(providerKey: String): MangaSource? {
        val sourceId = providerKey.removePrefix(MANGA_PROVIDER_KEY_PREFIX).toLongOrNull() ?: return null
        return mangaSources[sourceId]
    }

    private fun emptyPage(): Map<String, Any?> = mapOf(
        "items" to emptyList<Map<String, Any?>>(),
        "hasNextPage" to false,
    )

    private fun safeFilters(source: AnimeCatalogueSource): AnimeFilterList = runCatching { source.getFilterList() }.getOrDefault(AnimeFilterList())

    private fun safeFilters(source: MangaCatalogueSource): FilterList = runCatching { source.getFilterList() }.getOrDefault(FilterList())

    private fun animeFilterToMap(filter: AnimeFilter<*>): Map<String, Any?> = when (filter) {
        is AnimeFilter.Header -> mapOf("type" to "header", "name" to filter.name)
        is AnimeFilter.Separator -> mapOf("type" to "separator", "name" to filter.name)
        is AnimeFilter.Select<*> -> mapOf(
            "type" to "select",
            "name" to filter.name,
            "values" to filter.values.map { it.toString() },
            "state" to filter.state,
        )
        is AnimeFilter.Text -> mapOf("type" to "text", "name" to filter.name, "state" to filter.state)
        is AnimeFilter.CheckBox -> mapOf("type" to "checkbox", "name" to filter.name, "state" to filter.state)
        is AnimeFilter.TriState -> mapOf("type" to "tristate", "name" to filter.name, "state" to filter.state)
        is AnimeFilter.Group<*> -> mapOf(
            "type" to "group",
            "name" to filter.name,
            "filters" to filter.state.mapNotNull { child -> (child as? AnimeFilter<*>)?.let(::animeFilterToMap) },
        )
        is AnimeFilter.Sort -> mapOf(
            "type" to "sort",
            "name" to filter.name,
            "values" to filter.values.toList(),
            "state" to filter.state?.let { mapOf("index" to it.index, "ascending" to it.ascending) },
        )
    }

    private fun mangaFilterToMap(filter: MangaFilter<*>): Map<String, Any?> = when (filter) {
        is MangaFilter.Header -> mapOf("type" to "header", "name" to filter.name)
        is MangaFilter.Separator -> mapOf("type" to "separator", "name" to filter.name)
        is MangaFilter.Select<*> -> mapOf(
            "type" to "select",
            "name" to filter.name,
            "values" to filter.values.map { it.toString() },
            "state" to filter.state,
        )
        is MangaFilter.Text -> mapOf("type" to "text", "name" to filter.name, "state" to filter.state)
        is MangaFilter.CheckBox -> mapOf("type" to "checkbox", "name" to filter.name, "state" to filter.state)
        is MangaFilter.TriState -> mapOf("type" to "tristate", "name" to filter.name, "state" to filter.state)
        is MangaFilter.Group<*> -> mapOf(
            "type" to "group",
            "name" to filter.name,
            "filters" to filter.state.mapNotNull { child -> (child as? MangaFilter<*>)?.let(::mangaFilterToMap) },
        )
        is MangaFilter.Sort -> mapOf(
            "type" to "sort",
            "name" to filter.name,
            "values" to filter.values.toList(),
            "state" to filter.state?.let { mapOf("index" to it.index, "ascending" to it.ascending) },
        )
    }

    private fun appliedAnimeFilters(
        source: AnimeCatalogueSource,
        filterStates: List<Map<String, Any?>>?,
    ): AnimeFilterList {
        val filters = safeFilters(source)
        if (filterStates.isNullOrEmpty()) return filters
        filterStates.forEach { state ->
            val path = (state["path"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: return@forEach
            if (path.isEmpty()) return@forEach
            var current: AnimeFilter<*>? = filters.getOrNull(path.first())
            for (childIndex in path.drop(1)) {
                val group = current as? AnimeFilter.Group<*> ?: return@forEach
                current = group.state.getOrNull(childIndex) as? AnimeFilter<*>
            }
            applyAnimeFilterState(current ?: return@forEach, state["state"])
        }
        return filters
    }

    private fun applyAnimeFilterState(filter: AnimeFilter<*>, value: Any?) {
        runCatching {
            when (filter) {
                is AnimeFilter.Select<*> -> filter.state = (value as Number).toInt()
                is AnimeFilter.Text -> filter.state = value?.toString().orEmpty()
                is AnimeFilter.CheckBox -> filter.state = value as Boolean
                is AnimeFilter.TriState -> filter.state = (value as Number).toInt()
                is AnimeFilter.Sort -> {
                    val map = value as? Map<*, *> ?: return@runCatching
                    filter.state = AnimeFilter.Sort.Selection(
                        (map["index"] as? Number)?.toInt() ?: 0,
                        map["ascending"] as? Boolean ?: false,
                    )
                }
                else -> Unit
            }
        }
    }

    private fun appliedMangaFilters(
        source: MangaCatalogueSource,
        filterStates: List<Map<String, Any?>>?,
    ): FilterList {
        val filters = safeFilters(source)
        if (filterStates.isNullOrEmpty()) return filters
        filterStates.forEach { state ->
            val path = (state["path"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: return@forEach
            if (path.isEmpty()) return@forEach
            var current: MangaFilter<*>? = filters.getOrNull(path.first())
            for (childIndex in path.drop(1)) {
                val group = current as? MangaFilter.Group<*> ?: return@forEach
                current = group.state.getOrNull(childIndex) as? MangaFilter<*>
            }
            applyMangaFilterState(current ?: return@forEach, state["state"])
        }
        return filters
    }

    private fun applyMangaFilterState(filter: MangaFilter<*>, value: Any?) {
        runCatching {
            when (filter) {
                is MangaFilter.Select<*> -> filter.state = (value as Number).toInt()
                is MangaFilter.Text -> filter.state = value?.toString().orEmpty()
                is MangaFilter.CheckBox -> filter.state = value as Boolean
                is MangaFilter.TriState -> filter.state = (value as Number).toInt()
                is MangaFilter.Sort -> {
                    val map = value as? Map<*, *> ?: return@runCatching
                    filter.state = MangaFilter.Sort.Selection(
                        (map["index"] as? Number)?.toInt() ?: 0,
                        map["ascending"] as? Boolean ?: false,
                    )
                }
                else -> Unit
            }
        }
    }

    private fun privatePackageInfo(pkgName: String): PackageInfo? {
        val file = File(extensionDir, "$pkgName.$PRIVATE_EXTENSION_EXTENSION")
        return if (file.isFile) archivePackageInfo(file) else null
    }

    private fun installedPackageInfo(pkgName: String): PackageInfo? {
        return runCatching { appContext.packageManager.getPackageInfo(pkgName, PACKAGE_FLAGS) }.getOrNull()
            ?.takeIf { isPackageAnExtension(it) }
    }

    private fun archivePackageInfo(file: File): PackageInfo? {
        return appContext.packageManager.getPackageArchiveInfo(file.absolutePath, PACKAGE_FLAGS)
            ?.also { it.applicationInfo?.fixBasePaths(file.absolutePath) }
    }

    private fun ApplicationInfo.fixBasePaths(path: String) {
        sourceDir = path
        publicSourceDir = path
    }

    private fun packageLabel(appInfo: ApplicationInfo): String = runCatching {
        appContext.packageManager.getApplicationLabel(appInfo).toString()
    }.getOrDefault(appInfo.packageName)

    private fun isPackageAnExtension(pkgInfo: PackageInfo): Boolean {
        return packageMediaType(pkgInfo) != null
    }

    private fun packageMediaType(pkgInfo: PackageInfo): ExtensionMediaType? {
        val features = pkgInfo.reqFeatures?.mapNotNull { it.name }.orEmpty()
        val metadata = pkgInfo.applicationInfo?.metaData ?: return null
        return when {
            features.contains(ANIME_EXTENSION_FEATURE) && metadata.containsKey(ANIME_METADATA_SOURCE_CLASS) -> ExtensionMediaType.Anime
            features.contains(MANGA_EXTENSION_FEATURE) && metadata.containsKey(MANGA_METADATA_SOURCE_CLASS) -> ExtensionMediaType.Manga
            else -> null
        }
    }

    private fun metadataSourceClass(mediaType: ExtensionMediaType): String = when (mediaType) {
        ExtensionMediaType.Anime -> ANIME_METADATA_SOURCE_CLASS
        ExtensionMediaType.Manga -> MANGA_METADATA_SOURCE_CLASS
    }

    private fun metadataNsfw(mediaType: ExtensionMediaType): String = when (mediaType) {
        ExtensionMediaType.Anime -> ANIME_METADATA_NSFW
        ExtensionMediaType.Manga -> MANGA_METADATA_NSFW
    }

    private fun inferAvailableMediaType(name: String, pkgName: String, apkName: String): ExtensionMediaType {
        val text = listOf(name, pkgName, apkName).joinToString(" ").lowercase(Locale.ROOT)
        return when {
            text.contains("aniyomi") || text.contains("animeextension") -> ExtensionMediaType.Anime
            else -> ExtensionMediaType.Manga
        }
    }

    private fun isSupportedLibVersion(mediaType: ExtensionMediaType, version: Double): Boolean {
        return when (mediaType) {
            ExtensionMediaType.Anime -> version >= ANIME_LIB_VERSION_MIN && version <= ANIME_LIB_VERSION_MAX
            ExtensionMediaType.Manga -> version >= MANGA_LIB_VERSION_MIN && version <= MANGA_LIB_VERSION_MAX
        }
    }

    @SuppressLint("PackageManagerGetSignatures")
    private fun getSignatures(pkgInfo: PackageInfo): List<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pkgInfo.signingInfo?.apkContentsSigners ?: pkgInfo.signatures
        } else {
            pkgInfo.signatures
        } ?: return emptyList()
        return signatures.map { signature -> sha256(signature.toByteArray()) }
    }

    private fun sha256(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun PackageInfo.versionCodeCompat(): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode else versionCode.toLong()

    private fun extractLibVersion(versionName: String): Double? = versionName.substringBeforeLast('.').toDoubleOrNull()

    private fun normalizeRepo(input: String): String {
        var trimmed = input.trim().removeSuffix("/")
        // Accept pasted GitHub web links and convert them to raw content URLs.
        if (trimmed.contains("github.com") && (trimmed.contains("/blob/") || trimmed.contains("/tree/"))) {
            trimmed = trimmed
                .replace("github.com", "raw.githubusercontent.com")
                .replace("/blob/", "/")
                .replace("/tree/", "/")
        }
        require(trimmed.startsWith("https://")) { "Extension repos must use HTTPS" }
        return trimmed.removeSuffix("/index.min.json").removeSuffix("/")
    }

    private fun statusName(status: Int): String? = when (status) {
        SAnime.ONGOING -> "Ongoing"
        SAnime.COMPLETED -> "Completed"
        SAnime.LICENSED -> "Licensed"
        SAnime.PUBLISHING_FINISHED -> "Publishing finished"
        SAnime.CANCELLED -> "Cancelled"
        SAnime.ON_HIATUS -> "On hiatus"
        else -> null
    }

    private fun mangaStatusName(status: Int): String? = when (status) {
        SManga.ONGOING -> "Ongoing"
        SManga.COMPLETED -> "Completed"
        SManga.LICENSED -> "Licensed"
        SManga.PUBLISHING_FINISHED -> "Publishing finished"
        SManga.CANCELLED -> "Cancelled"
        SManga.ON_HIATUS -> "On hiatus"
        else -> null
    }

    private sealed interface LoadResult {
        data class Success(val extension: LoadedExtensionInfo) : LoadResult
        data class Error(
            val message: String,
            val cause: Throwable? = null,
        ) : LoadResult
    }

    private data class ExtensionPackageCandidate(
        val pkgInfo: PackageInfo,
        val apkPath: String,
        val isPrivate: Boolean,
    )

    companion object {
        const val ANIME_PROVIDER_KEY_PREFIX = "aniyomi:"
        const val MANGA_PROVIDER_KEY_PREFIX = "aniyomi-manga:"
        const val KIND_POPULAR = "popular"
        const val KIND_LATEST = "latest"
        private const val ANIME_EXTENSION_FEATURE = "tachiyomi.animeextension"
        private const val MANGA_EXTENSION_FEATURE = "tachiyomi.extension"
        private const val ANIME_METADATA_SOURCE_CLASS = "tachiyomi.animeextension.class"
        private const val MANGA_METADATA_SOURCE_CLASS = "tachiyomi.extension.class"
        private const val ANIME_METADATA_NSFW = "tachiyomi.animeextension.nsfw"
        private const val MANGA_METADATA_NSFW = "tachiyomi.extension.nsfw"
        private const val PRIVATE_EXTENSION_EXTENSION = "ext"
        private const val PACKAGE_INSTALL_ACTION = "com.oneb.anikin.extensions.INSTALL_RESULT"
        private const val PACKAGE_UNINSTALL_ACTION = "com.oneb.anikin.extensions.UNINSTALL_RESULT"
        private const val PACKAGE_INSTALL_TIMEOUT_MS = 5 * 60 * 1000L
        private const val PACKAGE_VISIBILITY_RETRIES = 20
        private const val PACKAGE_VISIBILITY_RETRY_DELAY_MS = 100L
        private const val KEY_REPOS = "anime_extension_repos"
        private const val KEY_AVAILABLE_CACHE = "available_extensions_cache"
        private const val KEY_SHOW_NSFW = "show_nsfw_sources"
        private const val ANIME_LIB_VERSION_MIN = 12.0
        private const val ANIME_LIB_VERSION_MAX = 16.0
        private const val MANGA_LIB_VERSION_MIN = 1.0
        private const val MANGA_LIB_VERSION_MAX = 2.0
        private const val TAG = "AniyomiExtensions"
        private val PACKAGE_FLAGS = PackageManager.GET_CONFIGURATIONS or
            PackageManager.GET_META_DATA or
            PackageManager.GET_SIGNATURES or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else 0)

        fun isMangaProviderKey(providerKey: String): Boolean = providerKey.startsWith(MANGA_PROVIDER_KEY_PREFIX)

        @Volatile
        private var instance: AniyomiExtensionRuntime? = null

        fun get(context: Context): AniyomiExtensionRuntime = instance ?: synchronized(this) {
            instance ?: AniyomiExtensionRuntime(context.applicationContext).also { instance = it }
        }

        fun providerKeyForAnimeSource(sourceId: Long): String = "$ANIME_PROVIDER_KEY_PREFIX$sourceId"

        fun providerKeyForMangaSource(sourceId: Long): String = "$MANGA_PROVIDER_KEY_PREFIX$sourceId"
    }
}

private inline fun <reified T : Any> typeRef(): FullTypeReference<T> = object : FullTypeReference<T>() {}

private fun Throwable.describeForExtensionLoad(): String {
    val rootCause = generateSequence(this) { error -> error.cause }.last()
    val type = rootCause.javaClass.simpleName.ifBlank { rootCause.javaClass.name }
    return rootCause.message?.takeIf { it.isNotBlank() }?.let { "$type: $it" } ?: type
}
