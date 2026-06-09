package eu.kanade.tachiyomi.source.online

import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.util.asJsoup
import okhttp3.Response
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element

abstract class ParsedHttpSource : HttpSource() {
    override fun popularMangaParse(response: Response): MangasPage {
        val document = response.asJsoup()
        return MangasPage(
            document.select(popularMangaSelector()).map(::popularMangaFromElement),
            popularMangaNextPageSelector()?.let { document.select(it).first() } != null,
        )
    }

    protected abstract fun popularMangaSelector(): String
    protected abstract fun popularMangaFromElement(element: Element): SManga
    protected abstract fun popularMangaNextPageSelector(): String?

    override fun searchMangaParse(response: Response): MangasPage {
        val document = response.asJsoup()
        return MangasPage(
            document.select(searchMangaSelector()).map(::searchMangaFromElement),
            searchMangaNextPageSelector()?.let { document.select(it).first() } != null,
        )
    }

    protected abstract fun searchMangaSelector(): String
    protected abstract fun searchMangaFromElement(element: Element): SManga
    protected abstract fun searchMangaNextPageSelector(): String?

    override fun latestUpdatesParse(response: Response): MangasPage {
        val document = response.asJsoup()
        return MangasPage(
            document.select(latestUpdatesSelector()).map(::latestUpdatesFromElement),
            latestUpdatesNextPageSelector()?.let { document.select(it).first() } != null,
        )
    }

    protected abstract fun latestUpdatesSelector(): String
    protected abstract fun latestUpdatesFromElement(element: Element): SManga
    protected abstract fun latestUpdatesNextPageSelector(): String?

    override fun mangaDetailsParse(response: Response): SManga = mangaDetailsParse(response.asJsoup())
    protected abstract fun mangaDetailsParse(document: Document): SManga

    override fun chapterListParse(response: Response): List<SChapter> =
        response.asJsoup().select(chapterListSelector()).map(::chapterFromElement)

    protected abstract fun chapterListSelector(): String
    protected abstract fun chapterFromElement(element: Element): SChapter

    override fun pageListParse(response: Response): List<Page> =
        response.asJsoup().select(pageListSelector()).mapIndexed(::pageFromElement)

    protected abstract fun pageListSelector(): String
    protected abstract fun pageFromElement(index: Int, element: Element): Page

    override fun imageUrlParse(response: Response): String = imageUrlParse(response.asJsoup())
    protected open fun imageUrlParse(document: Document): String = ""
}