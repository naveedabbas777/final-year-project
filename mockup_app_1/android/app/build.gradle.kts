plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // Google Services plugin for Firebase
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin
}

android {
    namespace = "com.example.mockup_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.mockup_app"
        minSdk = flutter.minSdkVersion // ✅ Set to match Firebase min requirement
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    compileOptions {
        // AGP 8.5.x uses Java 17 toolchain; match Flutter requirements
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        // Allow use of experimental/opt-in APIs where plugins use @RequiresOptIn.
        // This reduces 'this API is experimental' warnings from some libraries.
        freeCompilerArgs += listOf("-Xopt-in=kotlin.RequiresOptIn")
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
    // 📦 Firebase BoM (Bill of Materials) - Compatible with Dart Firebase versions
    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))

    // Force Kotlin stdlib to 2.0.21 to avoid 2.1 metadata until R8 supports it
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:2.0.21"))

    // Firebase dependencies (versions managed by BoM)
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")
    implementation("org.jetbrains.kotlin:kotlin-stdlib")

    // Android desugaring for Java compatibility
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}

// Enforce Kotlin 2.0.21 across transitive dependencies to keep metadata at 2.0
configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "com.google.firebase" && requested.name == "firebase-core") {
            useVersion("21.1.1")
            because("Explicitly set firebase-core version for BoM 32.7.4 compatibility")
        }
        if (requested.group == "org.jetbrains.kotlin" && requested.version?.startsWith("2.1") == true) {
            useVersion("2.0.21")
            because("R8 in current AGP only supports Kotlin metadata up to 2.0")
        }
    }

    resolutionStrategy.eachDependency {
        if (requested.group == "androidx.core" && requested.name.startsWith("core")) {
            useVersion("1.13.1")
            because("Flutter text input on newer Android requires EditorInfoCompat APIs not present in 1.12.x")
        }
        if (requested.group == "androidx.activity") {
            useVersion("1.8.2")
            because("Keep activity artifacts compatible with AGP 8.7.x")
        }
        if (requested.group == "androidx.navigationevent") {
            useVersion("1.0.0")
            because("Avoid pulling navigationevent 1.0.2 which requires AGP 8.9.1")
        }
    }
}
