@file:Suppress("PropertyName")

package eu.kanade.tachiyomi.source.model

class SChapterImpl : SChapter {
    override var url: String = ""
    override var name: String = ""
    override var date_upload: Long = 0L
    override var chapter_number: Float = -1f
    override var scanlator: String? = null
}