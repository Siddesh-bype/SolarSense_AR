# TensorFlow Lite — keep GPU delegate classes (optional at runtime).
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend

# Play Core (used by Flutter deferred components on some SDK levels)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
