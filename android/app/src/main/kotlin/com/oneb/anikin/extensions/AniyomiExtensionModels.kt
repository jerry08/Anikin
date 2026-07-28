package com.oneb.anikin.extensions

import eu.kanade.tachiyomi.animesource.AnimeCatalogueSource
import eu.kanade.tachiyomi.animesource.AnimeSource
import eu.kanade.tachiyomi.animesource.ConfigurableAnimeSource
import eu.kanade.tachiyomi.source.CatalogueSource as MangaCatalogueSource
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.Source as MangaSource
import org.json.JSONArray
import org.json.JSONObject

enum class ExtensionMediaType(val wireName: String, val providerType: Int) {
    Anime("anime", 0),
    Manga("manga", 1);

    companion object {
        fun fromWireName(value: String?): ExtensionMediaType =
            entries.firstOrNull { it.wireName == value } ?: Anime
    }
}

enum class ExtensionInstallLocation(val wireName: String) {
    System("system"),
    Private("private"),
}

data class AvailableExtensionInfo(
    val name: String,
    val pkgName: String,
    val versionName: String,
    val versionCode: Long,
    val libVersion: Double,
    val lang: String,
    val isNsfw: Boolean,
    val mediaType: ExtensionMediaType,
    val apkName: String,
    val repoUrl: String,
    val iconUrl: String?,
    val sources: List<AvailableSourceInfo>,
) {
    fun toMap(
        installed: LoadedExtensionInfo? = null,
        failed: FailedExtensionInfo? = null,
    ): Map<String, Any?> {
        val installedVersionCode = installed?.versionCode ?: failed?.versionCode
        val installedLibVersion = installed?.libVersion ?: failed?.libVersion
        val installLocation = installed?.installLocation ?: failed?.installLocation
        val hasUpdate = installedVersionCode != null &&
            installedLibVersion != null &&
            (versionCode > installedVersionCode || libVersion > installedLibVersion)
        return mapOf(
            "name" to name,
            "pkgName" to pkgName,
            "versionName" to versionName,
            "versionCode" to versionCode,
            "libVersion" to libVersion,
            "lang" to lang,
            "isNsfw" to isNsfw,
            "mediaType" to mediaType.wireName,
            "type" to mediaType.providerType,
            "apkName" to apkName,
            "repoUrl" to repoUrl,
            "iconUrl" to iconUrl,
            "sources" to (installed?.sources?.mapNotNull(::sourceToMap) ?: sources.map { it.toMap() }),
            "isInstalled" to (installed != null || failed != null),
            "isLoaded" to (installed != null),
            "loadError" to failed?.loadError,
            "installLocation" to installLocation?.wireName,
            "isPrivate" to (installLocation == ExtensionInstallLocation.Private),
            "hasUpdate" to hasUpdate,
        )
    }

    fun toJson(): JSONObject = JSONObject()
        .put("name", name)
        .put("pkgName", pkgName)
        .put("versionName", versionName)
        .put("versionCode", versionCode)
        .put("libVersion", libVersion)
        .put("lang", lang)
        .put("isNsfw", isNsfw)
        .put("mediaType", mediaType.wireName)
        .put("apkName", apkName)
        .put("repoUrl", repoUrl)
        .put("iconUrl", iconUrl)
        .put(
            "sources",
            JSONArray().also { array -> sources.forEach { source -> array.put(source.toJson()) } },
        )

    companion object {
        fun fromJson(json: JSONObject): AvailableExtensionInfo? {
            val pkgName = json.optString("pkgName")
            if (pkgName.isEmpty()) return null
            val mediaType = ExtensionMediaType.fromWireName(json.optString("mediaType"))
            val sourcesJson = json.optJSONArray("sources")
            val sources = buildList {
                if (sourcesJson != null) {
                    for (index in 0 until sourcesJson.length()) {
                        val source = sourcesJson.optJSONObject(index) ?: continue
                        add(AvailableSourceInfo.fromJson(source, mediaType))
                    }
                }
            }
            return AvailableExtensionInfo(
                name = json.optString("name"),
                pkgName = pkgName,
                versionName = json.optString("versionName"),
                versionCode = json.optLong("versionCode"),
                libVersion = json.optDouble("libVersion", 0.0),
                lang = json.optString("lang"),
                isNsfw = json.optBoolean("isNsfw", false),
                mediaType = mediaType,
                apkName = json.optString("apkName"),
                repoUrl = json.optString("repoUrl"),
                iconUrl = json.optString("iconUrl").takeIf { it.isNotEmpty() },
                sources = sources,
            )
        }
    }
}

data class AvailableSourceInfo(
    val id: Long,
    val lang: String,
    val name: String,
    val baseUrl: String,
    val mediaType: ExtensionMediaType,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "key" to when (mediaType) {
            ExtensionMediaType.Anime -> AniyomiExtensionRuntime.providerKeyForAnimeSource(id)
            ExtensionMediaType.Manga -> AniyomiExtensionRuntime.providerKeyForMangaSource(id)
        },
        "name" to name,
        "language" to lang,
        "lang" to lang,
        "baseUrl" to baseUrl,
        "mediaType" to mediaType.wireName,
        "type" to mediaType.providerType,
    )

    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("lang", lang)
        .put("name", name)
        .put("baseUrl", baseUrl)

    companion object {
        fun fromJson(json: JSONObject, mediaType: ExtensionMediaType): AvailableSourceInfo =
            AvailableSourceInfo(
                id = json.optLong("id"),
                lang = json.optString("lang"),
                name = json.optString("name"),
                baseUrl = json.optString("baseUrl"),
                mediaType = mediaType,
            )
    }
}

data class LoadedExtensionInfo(
    val name: String,
    val pkgName: String,
    val versionName: String,
    val versionCode: Long,
    val libVersion: Double,
    val lang: String,
    val isNsfw: Boolean,
    val mediaType: ExtensionMediaType,
    val signatureHash: String,
    val installLocation: ExtensionInstallLocation,
    val sources: List<Any>,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "name" to name,
        "pkgName" to pkgName,
        "versionName" to versionName,
        "versionCode" to versionCode,
        "libVersion" to libVersion,
        "lang" to lang,
        "isNsfw" to isNsfw,
        "mediaType" to mediaType.wireName,
        "type" to mediaType.providerType,
        "signatureHash" to signatureHash,
        "installLocation" to installLocation.wireName,
        "isPrivate" to (installLocation == ExtensionInstallLocation.Private),
        "sources" to sources.mapNotNull { source -> sourceToMap(source) },
        "isInstalled" to true,
        "isLoaded" to true,
        "loadError" to null,
    )
}

data class FailedExtensionInfo(
    val name: String,
    val pkgName: String,
    val versionName: String,
    val versionCode: Long,
    val libVersion: Double,
    val lang: String,
    val isNsfw: Boolean,
    val mediaType: ExtensionMediaType,
    val signatureHash: String,
    val installLocation: ExtensionInstallLocation,
    val loadError: String,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "name" to name,
        "pkgName" to pkgName,
        "versionName" to versionName,
        "versionCode" to versionCode,
        "libVersion" to libVersion,
        "lang" to lang,
        "isNsfw" to isNsfw,
        "mediaType" to mediaType.wireName,
        "type" to mediaType.providerType,
        "signatureHash" to signatureHash,
        "installLocation" to installLocation.wireName,
        "isPrivate" to (installLocation == ExtensionInstallLocation.Private),
        "sources" to emptyList<Map<String, Any?>>(),
        "isInstalled" to true,
        "isLoaded" to false,
        "loadError" to loadError,
    )
}

private fun sourceToMap(source: Any): Map<String, Any?>? = when (source) {
    is AnimeSource -> mapOf(
        "id" to source.id,
        "key" to AniyomiExtensionRuntime.providerKeyForAnimeSource(source.id),
        "name" to source.name,
        "language" to source.lang,
        "lang" to source.lang,
        "mediaType" to ExtensionMediaType.Anime.wireName,
        "type" to ExtensionMediaType.Anime.providerType,
        "supportsLatest" to ((source as? AnimeCatalogueSource)?.supportsLatest ?: false),
        "isConfigurable" to (source is ConfigurableAnimeSource),
    )
    is MangaSource -> mapOf(
        "id" to source.id,
        "key" to AniyomiExtensionRuntime.providerKeyForMangaSource(source.id),
        "name" to source.name,
        "language" to source.lang,
        "lang" to source.lang,
        "mediaType" to ExtensionMediaType.Manga.wireName,
        "type" to ExtensionMediaType.Manga.providerType,
        "supportsLatest" to ((source as? MangaCatalogueSource)?.supportsLatest ?: false),
        "isConfigurable" to (source is ConfigurableSource),
    )
    else -> null
}
