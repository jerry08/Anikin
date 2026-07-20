package eu.kanade.tachiyomi.network.interceptor

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import okhttp3.Headers
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

abstract class WebViewInterceptor(
    private val context: Context,
    private val defaultUserAgentProvider: () -> String,
) : Interceptor {

    protected val mainHandler = Handler(Looper.getMainLooper())

    /**
     * When this is called, it initializes the WebView if it wasn't already. We use this to
     * avoid blocking the main thread too much.
     */
    private val initWebView by lazy {
        try {
            WebSettings.getDefaultUserAgent(context)
        } catch (_: Exception) {
            // Avoid crashes when Chrome/WebView is being updated.
        }
    }

    abstract fun shouldIntercept(response: Response): Boolean

    abstract fun intercept(chain: Interceptor.Chain, request: Request, response: Response): Response

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val response = chain.proceed(request)
        if (!shouldIntercept(response)) {
            return response
        }
        if (!supportsWebView(context)) {
            return response
        }
        initWebView

        return intercept(chain, request, response)
    }

    fun parseHeaders(headers: Headers): Map<String, String> {
        return headers
            // Keeping unsafe headers makes WebView throw [net::ERR_INVALID_ARGUMENT]
            .filter { (name, value) -> isRequestHeaderSafe(name, value) }
            .groupBy(keySelector = { (name, _) -> name }) { (_, value) -> value }
            .mapValues { it.value.getOrNull(0).orEmpty() }
    }

    fun CountDownLatch.awaitFor30Seconds() {
        await(30, TimeUnit.SECONDS)
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun createWebView(request: Request): WebView {
        return WebView(context).apply {
            with(settings) {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                useWideViewPort = true
                loadWithOverviewMode = true
                cacheMode = WebSettings.LOAD_DEFAULT
            }
            // Avoid sending empty User-Agent; Chromium WebView resets to default if empty.
            settings.userAgentString = request.header("User-Agent") ?: defaultUserAgentProvider()
        }
    }

    private fun supportsWebView(context: Context): Boolean {
        try {
            // May throw MissingWebViewPackageException if WebView is not installed.
            CookieManager.getInstance()
        } catch (error: Throwable) {
            return false
        }
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_WEBVIEW)
    }
}

@Suppress("OverridingDeprecatedMember", "DEPRECATION")
abstract class WebViewClientCompat : WebViewClient() {

    open fun onReceivedErrorCompat(
        view: WebView,
        errorCode: Int,
        description: String?,
        failingUrl: String,
        isMainFrame: Boolean,
    ) {
    }

    final override fun onReceivedError(
        view: WebView,
        request: WebResourceRequest,
        error: WebResourceError,
    ) {
        onReceivedErrorCompat(
            view,
            error.errorCode,
            error.description?.toString(),
            request.url.toString(),
            request.isForMainFrame,
        )
    }

    final override fun onReceivedError(
        view: WebView,
        errorCode: Int,
        description: String?,
        failingUrl: String,
    ) {
        onReceivedErrorCompat(view, errorCode, description, failingUrl, failingUrl == view.url)
    }

    final override fun onReceivedHttpError(
        view: WebView,
        request: WebResourceRequest,
        error: WebResourceResponse,
    ) {
        onReceivedErrorCompat(
            view,
            error.statusCode,
            error.reasonPhrase,
            request.url.toString(),
            request.isForMainFrame,
        )
    }
}

// Based on [IsRequestHeaderSafe] in https://source.chromium.org/chromium/chromium/src/+/main:services/network/public/cpp/header_util.cc
private fun isRequestHeaderSafe(name: String, value: String): Boolean {
    val nameLower = name.lowercase(Locale.ENGLISH)
    val valueLower = value.lowercase(Locale.ENGLISH)
    if (nameLower in unsafeHeaderNames || nameLower.startsWith("proxy-")) return false
    return !(nameLower == "connection" && valueLower == "upgrade")
}

private val unsafeHeaderNames = listOf(
    "content-length",
    "host",
    "trailer",
    "te",
    "upgrade",
    "cookie2",
    "keep-alive",
    "transfer-encoding",
    "set-cookie",
)
