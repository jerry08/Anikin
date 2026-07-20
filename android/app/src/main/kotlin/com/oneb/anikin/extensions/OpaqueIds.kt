package com.oneb.anikin.extensions

import android.util.Base64
import eu.kanade.tachiyomi.animesource.model.AnimeUpdateStrategy
import eu.kanade.tachiyomi.animesource.model.FetchType
import eu.kanade.tachiyomi.animesource.model.SAnime
import eu.kanade.tachiyomi.animesource.model.SEpisode
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.UpdateStrategy
import org.json.JSONObject

object OpaqueIds {
    fun animeId(sourceId: Long, anime: SAnime): String = encode(
        JSONObject()
            .put("sourceId", sourceId)
            .put("url", anime.url)
            .put("title", anime.title)
            .put("artist", anime.artist)
            .put("author", anime.author)
            .put("description", anime.description)
            .put("genre", anime.genre)
            .put("status", anime.status)
            .put("thumbnailUrl", anime.thumbnail_url)
            .put("backgroundUrl", anime.background_url)
            .put("initialized", anime.initialized)
            .put("seasonNumber", anime.season_number)
            .put("fetchType", anime.fetch_type.name)
            .put("updateStrategy", anime.update_strategy.name),
    )

    fun episodeId(sourceId: Long, episode: SEpisode): String = encode(
        episodeJson(episode).put("sourceId", sourceId),
    )

    fun hosterId(sourceId: Long, episode: SEpisode, index: Int, name: String): String = encode(
        JSONObject()
            .put("kind", "hoster")
            .put("sourceId", sourceId)
            .put("index", index)
            .put("hosterName", name)
            .put("episode", episodeJson(episode)),
    )

    private fun episodeJson(episode: SEpisode): JSONObject = JSONObject()
        .put("url", episode.url)
        .put("name", episode.name)
        .put("dateUpload", episode.date_upload)
        .put("episodeNumber", episode.episode_number.toDouble())
        .put("fillermark", episode.fillermark)
        .put("scanlator", episode.scanlator)
        .put("summary", episode.summary)
        .put("previewUrl", episode.preview_url)

    fun mangaId(sourceId: Long, manga: SManga): String = encode(
        JSONObject()
            .put("sourceId", sourceId)
            .put("url", manga.url)
            .put("title", manga.title)
            .put("artist", manga.artist)
            .put("author", manga.author)
            .put("description", manga.description)
            .put("genre", manga.genre)
            .put("status", manga.status)
            .put("thumbnailUrl", manga.thumbnail_url)
            .put("initialized", manga.initialized)
            .put("updateStrategy", manga.update_strategy.name),
    )

    fun chapterId(sourceId: Long, chapter: SChapter): String = encode(
        JSONObject()
            .put("sourceId", sourceId)
            .put("url", chapter.url)
            .put("name", chapter.name)
            .put("dateUpload", chapter.date_upload)
            .put("chapterNumber", chapter.chapter_number.toDouble())
            .put("scanlator", chapter.scanlator),
    )

    fun decodeAnime(id: String): Pair<Long, SAnime>? = runCatching {
        val json = decode(id)
        val anime = SAnime.create().apply {
            url = json.optString("url")
            title = json.optString("title")
            artist = json.optNullableString("artist")
            author = json.optNullableString("author")
            description = json.optNullableString("description")
            genre = json.optNullableString("genre")
            status = json.optInt("status", SAnime.UNKNOWN)
            thumbnail_url = json.optNullableString("thumbnailUrl")
            background_url = json.optNullableString("backgroundUrl")
            initialized = json.optBoolean("initialized", false)
            season_number = json.optDouble("seasonNumber", -1.0)
            fetch_type = runCatching { FetchType.valueOf(json.optString("fetchType")) }.getOrDefault(FetchType.Episodes)
            update_strategy = runCatching { AnimeUpdateStrategy.valueOf(json.optString("updateStrategy")) }
                .getOrDefault(AnimeUpdateStrategy.ALWAYS_UPDATE)
        }
        json.getLong("sourceId") to anime
    }.getOrNull()

    fun decodeEpisode(id: String): Pair<Long, SEpisode>? = runCatching {
        val json = decode(id)
        if (json.optString("kind") == "hoster") return@runCatching null
        json.getLong("sourceId") to episodeFromJson(json)
    }.getOrNull()

    data class HosterRef(
        val sourceId: Long,
        val episode: SEpisode,
        val index: Int,
        val name: String,
    )

    fun decodeHoster(id: String): HosterRef? = runCatching {
        val json = decode(id)
        if (json.optString("kind") != "hoster") return@runCatching null
        val episodeJson = json.optJSONObject("episode") ?: return@runCatching null
        HosterRef(
            sourceId = json.getLong("sourceId"),
            episode = episodeFromJson(episodeJson),
            index = json.optInt("index", 0),
            name = json.optString("hosterName"),
        )
    }.getOrNull()

    private fun episodeFromJson(json: JSONObject): SEpisode = SEpisode.create().apply {
        url = json.optString("url")
        name = json.optString("name")
        date_upload = json.optLong("dateUpload", 0L)
        episode_number = json.optDouble("episodeNumber", -1.0).toFloat()
        fillermark = json.optBoolean("fillermark", false)
        scanlator = json.optNullableString("scanlator")
        summary = json.optNullableString("summary")
        preview_url = json.optNullableString("previewUrl")
    }

    fun decodeManga(id: String): Pair<Long, SManga>? = runCatching {
        val json = decode(id)
        val manga = SManga.create().apply {
            url = json.optString("url")
            title = json.optString("title")
            artist = json.optNullableString("artist")
            author = json.optNullableString("author")
            description = json.optNullableString("description")
            genre = json.optNullableString("genre")
            status = json.optInt("status", SManga.UNKNOWN)
            thumbnail_url = json.optNullableString("thumbnailUrl")
            initialized = json.optBoolean("initialized", false)
            update_strategy = runCatching { UpdateStrategy.valueOf(json.optString("updateStrategy")) }
                .getOrDefault(UpdateStrategy.ALWAYS_UPDATE)
        }
        json.getLong("sourceId") to manga
    }.getOrNull()

    fun decodeChapter(id: String): Pair<Long, SChapter>? = runCatching {
        val json = decode(id)
        val chapter = SChapter.create().apply {
            url = json.optString("url")
            name = json.optString("name")
            date_upload = json.optLong("dateUpload", 0L)
            chapter_number = json.optDouble("chapterNumber", -1.0).toFloat()
            scanlator = json.optNullableString("scanlator")
        }
        json.getLong("sourceId") to chapter
    }.getOrNull()

    private fun encode(json: JSONObject): String = Base64.encodeToString(
        json.toString().toByteArray(Charsets.UTF_8),
        Base64.URL_SAFE or Base64.NO_WRAP,
    )

    private fun decode(id: String): JSONObject = JSONObject(
        String(Base64.decode(id, Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8),
    )

    private fun JSONObject.optNullableString(name: String): String? {
        if (!has(name) || isNull(name)) return null
        return optString(name).takeIf { it.isNotEmpty() }
    }
}