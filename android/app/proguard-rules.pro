# ARCore — Session and friends are constructed from native/JNI code, so R8 has
# no visible reference to keep them alive. Without these rules the release build
# strips them and the AR screen dies at runtime (debug builds are unaffected,
# which is why this only shows up on a signed APK).
-keep class com.google.ar.core.** { *; }
-dontwarn com.google.ar.core.**

# Anything with native methods must keep its name for JNI lookup.
-keepclasseswithmembernames class * {
    native <methods>;
}

# TensorFlow Lite — keep GPU delegate classes (optional at runtime).
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend

# Play Core (used by Flutter deferred components on some SDK levels)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
