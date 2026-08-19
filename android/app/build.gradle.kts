import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ──────────────────────────────────────────────────────────
// Baca dari android/key.properties (TIDAK di-commit ke repo).
// Lihat key.properties.example dan SIGNING.md untuk cara setup.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore: Boolean = keystorePropertiesFile.exists()
if (hasKeystore) {
    FileInputStream(keystorePropertiesFile).use { fis ->
        keystoreProperties.load(fis)
    }
}

fun requireReleaseSigningConfig() {
    if (!hasKeystore) {
        throw GradleException(
            "Release signing config tidak ditemukan. Buat android/key.properties dan keystore release sebelum build release.",
        )
    }
    val requiredKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    for (key in requiredKeys) {
        val value = keystoreProperties.getProperty(key)?.trim().orEmpty()
        if (value.isEmpty()) {
            throw GradleException(
                "Release signing tidak valid: '$key' kosong di android/key.properties.",
            )
        }
    }
}

android {
    namespace = "com.kasirdapur.app"

    // ── SDK Versions ──────────────────────────────────────────────────────
    // targetSdk 35 — memenuhi Google Play requirement (update Agustus 2026).
    // compileSdk 36 — tersedia lokal; permission_handler warning diabaikan via
    // subprojects override di build.gradle.kts root.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kasirdapur.app"
        // minSdk 21 = Android 5.0 Lollipop — cover ~99% perangkat aktif
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── Signing ───────────────────────────────────────────────────────────
    if (hasKeystore) {
        signingConfigs {
            create("release") {
                keyAlias     = keystoreProperties.getProperty("keyAlias")
                keyPassword  = keystoreProperties.getProperty("keyPassword")
                storeFile    = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    // ── Build Types ───────────────────────────────────────────────────────
    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix   = "-debug"
        }

        release {
            if (!hasKeystore) {
                throw GradleException(
                    "Build type release wajib memakai release keystore. Debug signing tidak diizinkan untuk release.",
                )
            }
            signingConfig = signingConfigs.getByName("release")

            // R8 full mode — shrink + obfuscate
            isMinifyEnabled    = true
            isShrinkResources  = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

tasks.configureEach {
    val releaseTask = name.contains("Release", ignoreCase = true)
    val signingTask = name.startsWith("validateSigning", ignoreCase = true)
    if (releaseTask || signingTask) {
        doFirst {
            requireReleaseSigningConfig()
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
