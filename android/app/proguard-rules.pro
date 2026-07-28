# Injekt's FullTypeReference reads the generic type from its anonymous subclass.
# R8 full mode requires both ends of that generic signature to be kept.
-keepattributes Signature
-if class uy.kohesive.injekt.api.FullTypeReference
-keep,allowobfuscation class uy.kohesive.injekt.api.FullTypeReference
-keep,allowobfuscation class * extends uy.kohesive.injekt.api.FullTypeReference

# Aniyomi extensions are compiled separately and call these host APIs directly.
# R8 cannot see those calls, so preserve the public extension ABI.
-keep,allowoptimization class eu.kanade.tachiyomi.** { public protected *; }

# These packages are deliberately resolved from the host by
# ChildFirstPathClassLoader and must remain available to extension APKs.
-keep,allowoptimization class androidx.preference.** { public protected *; }
-keep,allowoptimization class uy.kohesive.injekt.** { public protected *; }
-keep,allowoptimization class kotlin.** { public protected *; }
-keep,allowoptimization class kotlinx.coroutines.** { public protected *; }
-keep,allowoptimization class kotlinx.serialization.** { public protected *; }
-keep,allowoptimization class okhttp3.** { public protected *; }
-keep,allowoptimization class okio.** { public protected *; }
-keep,allowoptimization class org.jsoup.** { public protected *; }
-keep,allowoptimization class rx.** { public protected *; }

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
