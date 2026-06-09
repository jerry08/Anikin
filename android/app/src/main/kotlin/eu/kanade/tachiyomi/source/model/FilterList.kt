package eu.kanade.tachiyomi.source.model

data class FilterList(val list: List<Filter<*>>) : List<Filter<*>> by list {
    constructor(vararg filters: Filter<*>) : this(filters.asList())
}