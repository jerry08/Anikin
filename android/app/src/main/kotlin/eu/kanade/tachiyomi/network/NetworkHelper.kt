package eu.kanade.tachiyomi.network

import android.content.Context
import okhttp3.Cache
import okhttp3.OkHttpClient
import okhttp3.brotli.BrotliInterceptor
import java.io.File
import java.util.concurrent.TimeUnit

class NetworkHelper private constructor(context: Context) {
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .callTimeout(2, TimeUnit.MINUTES)
        .cache(Cache(File(context.cacheDir, "aniyomi_network_cache"), 10L * 1024L * 1024L))
        .addInterceptor { chain ->
            val request = chain.request()
            val hasUserAgent = request.headers.names().any { it.equals("User-Agent", ignoreCase = true) }
            val nextRequest = if (hasUserAgent) {
                request
            } else {
                request.newBuilder().header("User-Agent", defaultUserAgentProvider()).build()
            }
            chain.proceed(nextRequest)
        }
        .addNetworkInterceptor(BrotliInterceptor)
        .build()

    val cloudflareClient: OkHttpClient = client
    val nonCloudflareClient: OkHttpClient = client

    fun defaultUserAgentProvider(): String = DEFAULT_USER_AGENT

    companion object {
        private const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"

        @Volatile
        private var instance: NetworkHelper? = null

        fun initialize(context: Context) {
            if (instance == null) {
                instance = NetworkHelper(context.applicationContext)
            }
        }

        fun get(): NetworkHelper = instance
            ?: error("NetworkHelper is not initialized")
    }
}