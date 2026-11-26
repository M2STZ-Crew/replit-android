plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply Firebase's Google Services plugin ONLY when the config file is present,
// so the app still builds before FCM is set up. To activate push notifications,
// drop android/app/google-services.json in (Firebase Console -> Android app).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Google Play's copy (v1.12.44), built with
//   flutter build appbundle --android-project-arg=playStore=true
//     --dart-define=PLAY_STORE=true
// (.github/workflows/android-release.yml, docs/play-release.md). It is
// signed with the Play upload key and does not ask to install apps: Play
// updates it. Every other build is the APK page's, as before: the team's
// debug key, and its own updater.
val playStore = (project.findProperty("playStore") as String?) == "true"
val uploadKeystore = System.getenv("UPLOAD_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }

android {
    namespace = "com.m2stz.replit"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.m2stz.replit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Cloud Messaging requires API 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The permission to install a downloaded update: the APK page's copy
        // only (AndroidManifest.xml).
        manifestPlaceholders["installPermission"] =
            if (playStore) {
                "com.m2stz.replit.permission.UPDATED_BY_GOOGLE_PLAY"
            } else {
                "android.permission.REQUEST_INSTALL_PACKAGES"
            }
        // The location foreground service, for a dispatched responder's
        // position: the APK page's copy only. Play's copy is for residents
        // (v1.12.65), so it needs no foreground-service declaration.
        manifestPlaceholders["foregroundLocationPermission"] =
            if (playStore) {
                "com.m2stz.replit.permission.NO_FOREGROUND_LOCATION_ON_PLAY"
            } else {
                "android.permission.FOREGROUND_SERVICE_LOCATION"
            }
    }

    signingConfigs {
        uploadKeystore?.let { path ->
            create("upload") {
                storeFile = file(path)
                storePassword = System.getenv("UPLOAD_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // The APK page's copy: the team's debug key, which every installed
            // copy has (android-release.yml checks it). Google Play's copy: the
            // upload key; Play then signs what it hands out with its own.
            signingConfig =
                if (playStore) {
                    signingConfigs.findByName("upload")
                        ?: throw GradleException(
                            "The Google Play build needs the upload key: set UPLOAD_KEYSTORE_PATH " +
                                "and its passwords (docs/play-release.md).",
                        )
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider, which hands a downloaded update to Android's installer
    // (MainActivity.installUpdate, lib/updates/app_updates.dart).
    implementation("androidx.core:core-ktx:1.16.0")
}
