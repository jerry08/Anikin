package eu.kanade.tachiyomi.network

import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import rx.Observable
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

fun Call.asObservable(): Observable<Response> = Observable.create { subscriber ->
    val call = clone()
    try {
        val response = call.execute()
        if (!subscriber.isUnsubscribed) {
            subscriber.onNext(response)
            subscriber.onCompleted()
        }
    } catch (error: Throwable) {
        if (!subscriber.isUnsubscribed) subscriber.onError(error)
    }
}

fun Call.asObservableSuccess(): Observable<Response> = asObservable().doOnNext { response ->
    if (!response.isSuccessful) {
        response.close()
        throw HttpException(response.code)
    }
}

suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    enqueue(
        object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (!continuation.isCancelled) continuation.resumeWithException(e)
            }

            override fun onResponse(call: Call, response: Response) {
                continuation.resume(response)
            }
        },
    )
    continuation.invokeOnCancellation { cancel() }
}

suspend fun Call.awaitSuccess(): Response {
    val response = await()
    if (!response.isSuccessful) {
        response.close()
        throw HttpException(response.code)
    }
    return response
}

fun OkHttpClient.newCachelessCallWithProgress(request: okhttp3.Request, listener: ProgressListener): Call {
    val client = newBuilder()
        .cache(null)
        .addNetworkInterceptor(
            Interceptor { chain ->
                val response = chain.proceed(chain.request())
                listener.update(0, response.body?.contentLength() ?: -1, false)
                response
            },
        )
        .build()
    return client.newCall(request)
}

class HttpException(val code: Int) : IllegalStateException("HTTP error $code")