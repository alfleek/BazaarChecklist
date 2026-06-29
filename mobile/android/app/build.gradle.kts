plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Loads Android release signing credentials from a local-only `key.properties`
// file (kept out of git). Play Store uploads require a real release keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
// Only fail when the invoked Gradle tasks are actually release-related.
val isReleaseBuild = gradle.startParameter.taskNames.any { task ->
    task.lowercase().contains("release")
}
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.checklist.bazaar"
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
        applicationId = "com.checklist.bazaar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                if (isReleaseBuild) {
                    throw GradleException(
                        "Missing key.properties for Android release signing.\n" +
                        "Create `mobile/android/key.properties` (gitignored) and point it at your keystore,\n" +
                        "then retry: Flutter release build / Play upload."
                    )
                } else {
                    // Allows local builds when release credentials are not configured yet.
                    signingConfig = signingConfigs.getByName("debug")
                }
            } else {
                signingConfig = signingConfigs.create("release") {
                    // Typical `key.properties` values (gitignored):
                    // storePassword=...
                    // keyPassword=...
                    // keyAlias=...
                    // storeFile=upload-keystore.jks
                    storeFile = file(keystoreProperties["storeFile"].toString())
                    storePassword = keystoreProperties["storePassword"].toString()
                    keyAlias = keystoreProperties["keyAlias"].toString()
                    keyPassword = keystoreProperties["keyPassword"].toString()
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
