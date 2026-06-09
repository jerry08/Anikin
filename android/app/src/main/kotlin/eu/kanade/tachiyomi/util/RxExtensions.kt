package eu.kanade.tachiyomi.util

import kotlinx.coroutines.suspendCancellableCoroutine
import rx.Observable
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

suspend fun <T> Observable<T>.awaitSingle(): T = suspendCancellableCoroutine { continuation ->
    val subscription = single().subscribe(
        { value -> continuation.resume(value) },
        { error -> continuation.resumeWithException(error) },
    )
    continuation.invokeOnCancellation { subscription.unsubscribe() }
}