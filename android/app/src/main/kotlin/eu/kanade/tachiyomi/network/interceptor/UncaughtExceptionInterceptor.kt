package eu.kanade.tachiyomi.network.interceptor

import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * OkHttp can only propagate IOExceptions out of interceptors; anything else crashes the
 * process. Extensions run arbitrary code inside interceptors, so wrap their failures.
 */
class UncaughtExceptionInterceptor : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        return try {
            chain.proceed(chain.request())
        } catch (error: Exception) {
            if (error is IOException) {
                throw error
            } else {
                throw IOException(error)
            }
        }
    }
}
