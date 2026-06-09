package com.oneb.anikin.extensions

import eu.kanade.tachiyomi.animesource.AnimeSource
import eu.kanade.tachiyomi.source.Source as MangaSource

enum class ExtensionMediaType(val wireName: String, val providerType: Int) {
    Anime("anime", 0),
    Manga("manga", 1),
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
    fun toMap(installed: LoadedExtensionInfo? = null): Map<String, Any?> = mapOf(
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
        "sources" to sources.map { it.toMap() },
        "isInstalled" to (installed != null),
        "installLocation" to installed?.installLocation?.wireName,
        "isPrivate" to (installed?.installLocation == ExtensionInstallLocation.Private),
        "hasUpdate" to (installed?.let { versionCode > it.versionCode || libVersion > it.libVersion } ?: false),
    )
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
    )

    private fun sourceToMap(source: Any): Map<String, Any?>? = when (source) {
        is AnimeSource -> mapOf(
            "id" to source.id,
            "key" to AniyomiExtensionRuntime.providerKeyForAnimeSource(source.id),
            "name" to source.name,
            "language" to source.lang,
            "lang" to source.lang,
            "mediaType" to ExtensionMediaType.Anime.wireName,
            "type" to ExtensionMediaType.Anime.providerType,
        )
        is MangaSource -> mapOf(
            "id" to source.id,
            "key" to AniyomiExtensionRuntime.providerKeyForMangaSource(source.id),
            "name" to source.name,
            "language" to source.lang,
            "lang" to source.lang,
            "mediaType" to ExtensionMediaType.Manga.wireName,
            "type" to ExtensionMediaType.Manga.providerType,
        )
        else -> null
    }
}