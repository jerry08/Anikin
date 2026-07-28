package com.oneb.anikin.extensions

import dalvik.system.PathClassLoader

class ChildFirstPathClassLoader(path: String, parent: ClassLoader) : PathClassLoader(path, parent) {
    override fun loadClass(name: String, resolve: Boolean): Class<*> {
        synchronized(this) {
            findLoadedClass(name)?.let { return it }

            if (isParentFirst(name)) {
                return super.loadClass(name, resolve)
            }

            val loaded = try {
                findClass(name)
            } catch (_: ClassNotFoundException) {
                super.loadClass(name, resolve)
            }

            if (resolve) resolveClass(loaded)
            return loaded
        }
    }

    private fun isParentFirst(name: String): Boolean {
        return name.startsWith("java.") ||
            name.startsWith("javax.") ||
            name.startsWith("android.") ||
            name.startsWith("androidx.preference.") ||
            name.startsWith("kotlin.") ||
            name.startsWith("kotlinx.coroutines.") ||
            name.startsWith("kotlinx.serialization.") ||
            name.startsWith("okhttp3.") ||
            name.startsWith("okio.") ||
            name.startsWith("org.jsoup.") ||
            name.startsWith("rx.") ||
            name.startsWith("app.cash.quickjs.") ||
            name.startsWith("uy.kohesive.injekt.") ||
            name.startsWith("eu.kanade.tachiyomi.animesource.") ||
            name.startsWith("eu.kanade.tachiyomi.source.") ||
            name.startsWith("eu.kanade.tachiyomi.network.") ||
            name.startsWith("eu.kanade.tachiyomi.util.")
    }
}
