plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("MAPASJW_KEYSTORE_PATH")
val releaseKeyAlias = System.getenv("MAPASJW_KEY_ALIAS")
val releaseStorePassword = System.getenv("MAPASJW_STORE_PASSWORD")
val releaseKeyPassword = System.getenv("MAPASJW_KEY_PASSWORD")
val googleMapsApiKey = System.getenv("GOOGLE_MAPS_ANDROID_API_KEY")
val canSignRelease = listOf(
    releaseKeystorePath,
    releaseKeyAlias,
    releaseStorePassword,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "br.com.mapasjw.cartas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.mapasjw.cartas"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        manifestPlaceholders["MAPS_API_KEY"] =
            googleMapsApiKey?.takeIf { it.isNotBlank() } ?: "YOUR_GOOGLE_MAPS_ANDROID_API_KEY"
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (canSignRelease) {
        signingConfigs.create("release") {
            storeFile = file(releaseKeystorePath!!)
            keyAlias = releaseKeyAlias
            storePassword = releaseStorePassword
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = if (canSignRelease) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
