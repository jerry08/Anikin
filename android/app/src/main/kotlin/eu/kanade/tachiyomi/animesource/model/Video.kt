package eu.kanade.tachiyomi.animesource.model

import android.net.Uri
import okhttp3.Headers

data class Track(val url: String, val lang: String)

enum class ChapterType {
    Opening,
    Ending,
    Recap,
    MixedOp,
    Other,
}

data class TimeStamp(val start: Double, val end: Double, val name: String, val type: ChapterType = ChapterType.Other)

data class Video(
    var videoUrl: String = "",
    val videoTitle: String = "",
    val resolution: Int? = null,
    val bitrate: Int? = null,
    val headers: Headers? = null,
    val preferred: Boolean = false,
    val subtitleTracks: List<Track> = emptyList(),
    val audioTracks: List<Track> = emptyList(),
    val timestamps: List<TimeStamp> = emptyList(),
    val mpvArgs: List<Pair<String, String>> = emptyList(),
    val ffmpegStreamArgs: List<Pair<String, String>> = emptyList(),
    val ffmpegVideoArgs: List<Pair<String, String>> = emptyList(),
    val internalData: String = "",
    val initialized: Boolean = false,
) {
    @Deprecated("Use videoTitle instead")
    val quality: String
        get() = videoTitle

    @Deprecated("Use videoUrl instead")
    val url: String
        get() = videoPageUrl

    private var videoPageUrl: String = ""

    constructor(
        url: String,
        quality: String,
        videoUrl: String?,
        headers: Headers? = null,
        subtitleTracks: List<Track> = emptyList(),
        audioTracks: List<Track> = emptyList(),
    ) : this(
        videoUrl = videoUrl ?: "",
        videoTitle = quality,
        headers = headers,
        subtitleTracks = subtitleTracks,
        audioTracks = audioTracks,
    ) {
        videoPageUrl = url
    }

    @Suppress("UNUSED_PARAMETER")
    constructor(
        url: String,
        quality: String,
        videoUrl: String?,
        uri: Uri? = null,
        headers: Headers? = null,
    ) : this(url, quality, videoUrl, headers)

    enum class State { QUEUE, LOAD_VIDEO, READY, ERROR }

    @Transient
    @Volatile
    var status: State = State.QUEUE

    companion object {
        const val MPV_ARGS_TAG = "ANIYOMI_MPV_ARGS"
    }
}