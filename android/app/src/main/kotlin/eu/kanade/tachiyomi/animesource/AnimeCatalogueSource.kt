package eu.kanade.tachiyomi.animesource

import eu.kanade.tachiyomi.animesource.model.AnimeFilterList
import eu.kanade.tachiyomi.animesource.model.AnimesPage
import eu.kanade.tachiyomi.util.awaitSingle
import rx.Observable

interface AnimeCatalogueSource : AnimeSource {
    override val lang: String
    val supportsLatest: Boolean

    @Suppress("DEPRECATION")
    suspend fun getPopularAnime(page: Int): AnimesPage = fetchPopularAnime(page).awaitSingle()

    @Suppress("DEPRECATION")
    suspend fun getSearchAnime(page: Int, query: String, filters: AnimeFilterList): AnimesPage =
        fetchSearchAnime(page, query, filters).awaitSingle()

    @Suppress("DEPRECATION")
    suspend fun getLatestUpdates(page: Int): AnimesPage = fetchLatestUpdates(page).awaitSingle()

    fun getFilterList(): AnimeFilterList

    @Deprecated("Use getPopularAnime instead")
    fun fetchPopularAnime(page: Int): Observable<AnimesPage>

    @Deprecated("Use getSearchAnime instead")
    fun fetchSearchAnime(page: Int, query: String, filters: AnimeFilterList): Observable<AnimesPage>

    @Deprecated("Use getLatestUpdates instead")
    fun fetchLatestUpdates(page: Int): Observable<AnimesPage>
}