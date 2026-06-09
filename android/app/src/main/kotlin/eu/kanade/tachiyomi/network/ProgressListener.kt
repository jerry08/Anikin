package eu.kanade.tachiyomi.network

fun interface ProgressListener {
    fun update(bytesRead: Long, contentLength: Long, done: Boolean)
}