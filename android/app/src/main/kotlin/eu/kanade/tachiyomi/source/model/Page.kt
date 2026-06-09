package eu.kanade.tachiyomi.source.model

data class Page(
    val index: Int,
    val url: String = "",
    var imageUrl: String? = null,
)