package eu.kanade.tachiyomi.util

import okhttp3.Response
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element

fun Element.selectText(css: String, defaultValue: String? = null): String? = select(css).first()?.text() ?: defaultValue

fun Element.selectInt(css: String, defaultValue: Int = 0): Int = select(css).first()?.text()?.toIntOrNull() ?: defaultValue

fun Element.attrOrText(css: String): String = if (css == "text") text() else attr(css)

fun Response.asJsoup(html: String? = null): Document = Jsoup.parse(html ?: body?.string().orEmpty(), request.url.toString())