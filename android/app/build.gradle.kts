plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.solarsense_ar"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.solarsense_ar"
        minSdk = 26      // tflite_flutter requires 26; arsceneview needs >=24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Disable Flutter Impeller (Vulkan) — Filament/ARSceneView manages its
        // own GL context; both renderers conflict over AHardwareBuffer allocation.
        // resValue overrides the manifest meta-data at build time (most reliable method).
        resValue("string", "io_flutter_embedding_android_EnableImpeller", "false")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Required by Filament / SceneView — these files must NOT be compressed in APK.
    // GLB/GLTF: Filament memory-maps them directly (mmap fails on compressed streams).
    // filamat/ktx: Filament material bundles also require uncompressed access.
    aaptOptions {
        noCompress += listOf("filamat", "ktx", "glb", "gltf")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ARSceneView 2.x — Kotlin-first SceneView/ARCore wrapper (successor to Gorisse Sceneform)
    implementation("io.github.sceneview:arsceneview:2.2.1")
    // AndroidX core for ContextCompat, lifecycle
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
}
