plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "la.hrapp.hr_app"
    compileSdk = flutter.compileSdkVersion
    // The main SDK lives under Program Files (read-only), so the NDK (required by
    // native deps like Firebase / the :jni module) was installed to a writable
    // location instead. ndkPath points AGP straight at it (skipping the licence
    // check); ndkVersion must match the version that path contains.
    ndkVersion = flutter.ndkVersion
    ndkPath = "C:/Users/kpyou/AppData/Local/Android/Sdk/ndk/28.2.13676358"

    compileOptions {
        // Required by flutter_local_notifications (uses java.time APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "la.hrapp.hr_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Keep the native libraries shipped by dependencies (e.g. Firebase) as-is
    // instead of stripping their debug symbols. Stripping is the ONLY thing that
    // would pull in the NDK, and the NDK can't be installed here (the SDK lives
    // under Program Files, which isn't writable). This avoids a ~1GB download.
    packaging {
        jniLibs {
            keepDebugSymbols += "**/*.so"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backport of java.time for older Android (needed by flutter_local_notifications).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
