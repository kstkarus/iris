plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kstkarus.iris.iris"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.kstkarus.iris.iris"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "iris"
        manifestPlaceholders["authScheme"] = "iris"
    }

    buildTypes {
        // `flutter run` builds: an app of their own beside the installed
        // release, so a local build (version code 1) never replaces a newer
        // release and takes its data with it. Its own name and sign-in link,
        // or both apps would answer Shikimori's redirect.
        debug {
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "iris dev"
            manifestPlaceholders["authScheme"] = "iris-dev"
        }
        release {
            // Signed with the debug keystore on purpose: installed releases
            // carry its signature, and Android updates only over the same
            // one. CI decodes that keystore from a secret (see README).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
