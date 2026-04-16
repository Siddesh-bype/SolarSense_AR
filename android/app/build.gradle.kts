plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.solarsense_ar"
    compileSdk = 36
    // NDK version required by tflite_flutter, geolocator_android, webview_flutter_android etc.
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
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ARCore — real-world plane detection and tracking
    implementation("com.google.ar:core:1.40.0")
    // Sceneform community fork — Filament-based 3D rendering on ARCore planes
    implementation("com.gorisse.thomas.sceneform:sceneform:1.23.0")
    // ContextCompat.checkSelfPermission for camera guard
    implementation("androidx.core:core-ktx:1.13.1")
}

