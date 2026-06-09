package eu.kanade.tachiyomi.source

import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.util.awaitSingle
import rx.Observable

interface CatalogueSource : Source {
    override val lang: String
    val supportsLatest: Boolean

    @Suppress("DEPRECATION")
    suspend fun getPopularManga(page: Int): MangasPage = fetchPopularManga(page).awaitSingle()

    @Suppress("DEPRECATION")
    suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage =
        fetchSearchManga(page, query, filters).awaitSingle()

    @Suppress("DEPRECATION")
    suspend fun getLatestUpdates(page: Int): MangasPage = fetchLatestUpdates(page).awaitSingle()

    fun getFilterList(): FilterList

    @Deprecated("Use getPopularManga instead")
    fun fetchPopularManga(page: Int): Observable<MangasPage>

    @Deprecated("Use getSearchManga instead")
    fun fetchSearchManga(page: Int, query: String, filters: FilterList): Observable<MangasPage>

    @Deprecated("Use getLatestUpdates instead")
    fun fetchLatestUpdates(page: Int): Observable<MangasPage>
}