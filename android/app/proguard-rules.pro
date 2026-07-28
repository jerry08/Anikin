# Injekt's FullTypeReference reads the generic type from its anonymous subclass.
# R8 full mode requires both ends of that generic signature to be kept.
-keepattributes Signature
-if class uy.kohesive.injekt.api.FullTypeReference
-keep,allowobfuscation class uy.kohesive.injekt.api.FullTypeReference
-keep,allowobfuscation class * extends uy.kohesive.injekt.api.FullTypeReference

# Aniyomi extensions are compiled separately and call these host APIs directly.
# R8 cannot see those calls or external subclasses, so preserve the public
# extension ABI without optimization. In particular, allowing optimization can
# make open methods final and cause extension classes to fail verification.
-keep class eu.kanade.tachiyomi.** { public protected *; }

# These packages are deliberately resolved from the host by
# ChildFirstPathClassLoader. Preserve their externally visible ABI as well as
# their names because extension APKs can subclass and call into them.
-keep class androidx.preference.** { public protected *; }
-keep class uy.kohesive.injekt.** { public protected *; }
-keep class kotlin.** { public protected *; }
-keep class kotlinx.coroutines.** { public protected *; }
-keep class kotlinx.serialization.** { public protected *; }
-keep class okhttp3.** { public protected *; }
-keep class okio.** { public protected *; }
-keep class org.jsoup.** { public protected *; }
-keep class rx.** { public protected *; }
-keep class app.cash.quickjs.** { public protected *; }

# Compatibility rules used by the Aniyomi extension runtime.
-keepclasseswithmembers class okhttp3.MultipartBody$Builder { *; }

-keepclassmembers class rx.internal.util.unsafe.*ArrayQueue*Field* {
    long producerIndex;
    long consumerIndex;
}

-keepclassmembers class rx.internal.util.unsafe.BaseLinkedQueueProducerNodeRef {
    rx.internal.util.atomic.LinkedQueueNode producerNode;
}

-keepclassmembers class rx.internal.util.unsafe.BaseLinkedQueueConsumerNodeRef {
    rx.internal.util.atomic.LinkedQueueNode consumerNode;
}
