plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.timo_enginerring"
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
        applicationId = "com.timo.invoice"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // SECURITY: Configure with your own keystore in production.
            // Generate a signing key with:
            // keytool -genkey -v -keystore ~/timo-release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias timo_key
            //
            // Then set these environment variables before building for release:
            // export TIMO_KEYSTORE_PATH=~/timo-release.keystore
            // export TIMO_KEYSTORE_PASSWORD=your_keystore_password
            // export TIMO_KEY_ALIAS=timo_key
            // export TIMO_KEY_PASSWORD=your_key_password
            //
            // Or hard-code them here (NOT recommended for version control):
            storeFile = file(System.getenv("TIMO_KEYSTORE_PATH") ?: "timo-release.keystore")
            storePassword = System.getenv("TIMO_KEYSTORE_PASSWORD") ?: "changeme"
            keyAlias = System.getenv("TIMO_KEY_ALIAS") ?: "timo_key"
            keyPassword = System.getenv("TIMO_KEY_PASSWORD") ?: "changeme"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
