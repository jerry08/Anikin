package eu.kanade.tachiyomi.animesource

import eu.kanade.tachiyomi.animesource.model.Hoster
import eu.kanade.tachiyomi.animesource.model.SAnime
import eu.kanade.tachiyomi.animesource.model.SEpisode
import eu.kanade.tachiyomi.animesource.model.Video
import eu.kanade.tachiyomi.util.awaitSingle
import rx.Observable

interface AnimeSource {
    val id: Long
    val name: String

    val lang: String
        get() = ""

    @Suppress("DEPRECATION")
    suspend fun getAnimeDetails(anime: SAnime): SAnime = fetchAnimeDetails(anime).awaitSingle()

    @Suppress("DEPRECATION")
    suspend fun getEpisodeList(anime: SAnime): List<SEpisode> = fetchEpisodeList(anime).awaitSingle()

    suspend fun getSeasonList(anime: SAnime): List<SAnime> = emptyList()

    suspend fun getHosterList(episode: SEpisode): List<Hoster> = throw IllegalStateException("Not used")

    suspend fun getVideoList(hoster: Hoster): List<Video> = throw IllegalStateException("Not used")

    @Suppress("DEPRECATION")
    suspend fun getVideoList(episode: SEpisode): List<Video> = fetchVideoList(episode).awaitSingle()

    @Deprecated("Use getAnimeDetails instead")
    fun fetchAnimeDetails(anime: SAnime): Observable<SAnime> = throw IllegalStateException("Not used")

    @Deprecated("Use getEpisodeList instead")
    fun fetchEpisodeList(anime: SAnime): Observable<List<SEpisode>> = throw IllegalStateException("Not used")

    @Deprecated("Use getVideoList instead")
    fun fetchVideoList(episode: SEpisode): Observable<List<Video>> = throw IllegalStateException("Not used")
}