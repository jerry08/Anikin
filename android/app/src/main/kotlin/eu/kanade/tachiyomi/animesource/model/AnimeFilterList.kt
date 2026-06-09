package eu.kanade.tachiyomi.animesource.model

data class AnimeFilterList(val list: List<AnimeFilter<*>>) : List<AnimeFilter<*>> by list {
    constructor(vararg filters: AnimeFilter<*>) : this(filters.asList())
}