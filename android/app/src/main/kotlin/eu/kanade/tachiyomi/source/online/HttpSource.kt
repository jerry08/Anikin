package eu.kanade.tachiyomi.source.online

import eu.kanade.tachiyomi.network.GET
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.network.asObservableSuccess
import eu.kanade.tachiyomi.network.awaitSuccess
import eu.kanade.tachiyomi.source.CatalogueSource
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.util.awaitSingle
import okhttp3.Headers
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import rx.Observable
import java.security.MessageDigest

abstract class HttpSource : CatalogueSource {
    protected val network: NetworkHelper
        get() = NetworkHelper.get()

    abstract val baseUrl: String
    open val versionId: Int = 1
    override val id: Long by lazy { generateId(name, lang, versionId) }
    val headers: Headers by lazy { headersBuilder().build() }
    open val client: OkHttpClient
        get() = network.client

    protected fun generateId(name: String, lang: String, versionId: Int): Long {
        val key = "${name.lowercase()}/$lang/$versionId"
        val bytes = MessageDigest.getInstance("MD5").digest(key.toByteArray())
        return (0..7).map { (bytes[it].toLong() and 0xff) shl (8 * (7 - it)) }.reduce(Long::or) and Long.MAX_VALUE
    }

    protected open fun headersBuilder(): Headers.Builder = Headers.Builder().add("User-Agent", network.defaultUserAgentProvider())

    override fun toString(): String = "$name (${lang.uppercase()})"

    override fun getFilterList(): FilterList = FilterList()

    @Deprecated("Use getPopularManga instead")
    override fun fetchPopularManga(page: Int): Observable<MangasPage> =
        client.newCall(popularMangaRequest(page)).asObservableSuccess().map(::popularMangaParse)

    protected abstract fun popularMangaRequest(page: Int): Request
    protected abstract fun popularMangaParse(response: Response): MangasPage

    @Deprecated("Use getSearchManga instead")
    override fun fetchSearchManga(page: Int, query: String, filters: FilterList): Observable<MangasPage> =
        client.newCall(searchMangaRequest(page, query, filters)).asObservableSuccess().map(::searchMangaParse)

    protected abstract fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request
    protected abstract fun searchMangaParse(response: Response): MangasPage

    @Deprecated("Use getLatestUpdates instead")
    override fun fetchLatestUpdates(page: Int): Observable<MangasPage> =
        client.newCall(latestUpdatesRequest(page)).asObservableSuccess().map(::latestUpdatesParse)

    protected abstract fun latestUpdatesRequest(page: Int): Request
    protected abstract fun latestUpdatesParse(response: Response): MangasPage

    @Suppress("DEPRECATION")
    override suspend fun getMangaDetails(manga: SManga): SManga = fetchMangaDetails(manga).awaitSingle()

    @Deprecated("Use getMangaDetails instead")
    override fun fetchMangaDetails(manga: SManga): Observable<SManga> =
        client.newCall(mangaDetailsRequest(manga)).asObservableSuccess().map { mangaDetailsParse(it).apply { initialized = true } }

    open fun mangaDetailsRequest(manga: SManga): Request = GET(baseUrl + manga.url, headers)
    protected abstract fun mangaDetailsParse(response: Response): SManga

    @Suppress("DEPRECATION")
    override suspend fun getChapterList(manga: SManga): List<SChapter> = fetchChapterList(manga).awaitSingle()

    @Deprecated("Use getChapterList instead")
    override fun fetchChapterList(manga: SManga): Observable<List<SChapter>> =
        client.newCall(chapterListRequest(manga)).asObservableSuccess().map(::chapterListParse)

    protected open fun chapterListRequest(manga: SManga): Request = GET(baseUrl + manga.url, headers)
    protected abstract fun chapterListParse(response: Response): List<SChapter>

    @Suppress("DEPRECATION")
    override suspend fun getPageList(chapter: SChapter): List<Page> = fetchPageList(chapter).awaitSingle()

    @Deprecated("Use getPageList instead")
    override fun fetchPageList(chapter: SChapter): Observable<List<Page>> =
        client.newCall(pageListRequest(chapter)).asObservableSuccess().map(::pageListParse)

    protected open fun pageListRequest(chapter: SChapter): Request = GET(baseUrl + chapter.url, headers)
    protected abstract fun pageListParse(response: Response): List<Page>

    @Suppress("DEPRECATION")
    open suspend fun getImageUrl(page: Page): String = fetchImageUrl(page).awaitSingle()

    @Deprecated("Use getImageUrl instead")
    open fun fetchImageUrl(page: Page): Observable<String> =
        client.newCall(imageUrlRequest(page)).asObservableSuccess().map(::imageUrlParse)

    protected open fun imageUrlRequest(page: Page): Request = GET(page.url, headers)
    protected open fun imageUrlParse(response: Response): String = pageImageUrlParse(response)
    protected open fun pageImageUrlParse(response: Response): String = ""

    open suspend fun getImage(page: Page): Response = client.newCall(imageRequest(page)).awaitSuccess()

    protected open fun imageRequest(page: Page): Request = GET(page.imageUrl ?: page.url, headers)

    fun SChapter.setUrlWithoutDomain(url: String) {
        this.url = getUrlWithoutDomain(url)
    }

    fun SManga.setUrlWithoutDomain(url: String) {
        this.url = getUrlWithoutDomain(url)
    }

    fun getUrlWithoutDomain(orig: String): String {
        val trimmed = orig.trim()
        val start = trimmed.indexOf("//").takeIf { it >= 0 }?.let { trimmed.indexOf('/', it + 2) } ?: -1
        return if (start >= 0) trimmed.substring(start) else trimmed
    }
}