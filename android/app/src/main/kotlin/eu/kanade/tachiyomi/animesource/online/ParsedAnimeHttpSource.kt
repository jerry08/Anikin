package eu.kanade.tachiyomi.animesource.online

import eu.kanade.tachiyomi.animesource.model.AnimesPage
import eu.kanade.tachiyomi.animesource.model.Hoster
import eu.kanade.tachiyomi.animesource.model.SAnime
import eu.kanade.tachiyomi.animesource.model.SEpisode
import eu.kanade.tachiyomi.animesource.model.Video
import eu.kanade.tachiyomi.util.asJsoup
import okhttp3.Response
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element

abstract class ParsedAnimeHttpSource : AnimeHttpSource() {
    override fun popularAnimeParse(response: Response): AnimesPage {
        val document = response.asJsoup()
        return AnimesPage(
            document.select(popularAnimeSelector()).map(::popularAnimeFromElement),
            popularAnimeNextPageSelector()?.let { document.select(it).first() } != null,
        )
    }

    protected abstract fun popularAnimeSelector(): String
    protected abstract fun popularAnimeFromElement(element: Element): SAnime
    protected abstract fun popularAnimeNextPageSelector(): String?

    override fun searchAnimeParse(response: Response): AnimesPage {
        val document = response.asJsoup()
        return AnimesPage(
            document.select(searchAnimeSelector()).map(::searchAnimeFromElement),
            searchAnimeNextPageSelector()?.let { document.select(it).first() } != null,
        )
    }

    protected abstract fun searchAnimeSelector(): String
    protected abstract fun searchAnimeFromElement(element: Element): SAnime
    protected abstract fun searchAnimeNextPageSelector(): String?

    override fun latestUpdatesParse(response: Response): AnimesPage {
        val document = response.asJsoup()
        return AnimesPage(
            document.select(latestUpdatesSelector()).map(::latestUpdatesFromElement),
            latestUpdatesNextPageSelector()?.let { document.select(it).first() } != null,
        )
    }

    protected abstract fun latestUpdatesSelector(): String
    protected abstract fun latestUpdatesFromElement(element: Element): SAnime
    protected abstract fun latestUpdatesNextPageSelector(): String?

    override fun animeDetailsParse(response: Response): SAnime = animeDetailsParse(response.asJsoup())
    protected abstract fun animeDetailsParse(document: Document): SAnime

    override fun episodeListParse(response: Response): List<SEpisode> =
        response.asJsoup().select(episodeListSelector()).map(::episodeFromElement)

    protected abstract fun episodeListSelector(): String
    protected abstract fun episodeFromElement(element: Element): SEpisode

    override fun seasonListParse(response: Response): List<SAnime> =
        response.asJsoup().select(seasonListSelector()).map(::seasonFromElement)

    protected open fun seasonListSelector(): String = ""
    protected open fun seasonFromElement(element: Element): SAnime = SAnime.create()

    override fun hosterListParse(response: Response): List<Hoster> =
        response.asJsoup().select(hosterListSelector()).map(::hosterFromElement)

    protected open fun hosterListSelector(): String = ""
    protected open fun hosterFromElement(element: Element): Hoster = Hoster()

    override fun videoListParse(response: Response): List<Video> =
        response.asJsoup().select(videoListSelector()).map(::videoFromElement)

    protected abstract fun videoListSelector(): String
    protected abstract fun videoFromElement(element: Element): Video

    override fun videoUrlParse(response: Response): String = videoUrlParse(response.asJsoup())
    protected abstract fun videoUrlParse(document: Document): String
}