plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Read SDK versions from gradle.properties — permanent, IDE won't override these
val mortarMinSdk = (project.properties["MORTAR_MIN_SDK"] as String? ?: "21").toInt()
val mortarCompileSdk = (project.properties["MORTAR_COMPILE_SDK"] as String? ?: "36").toInt()
val mortarTargetSdk = (project.properties["MORTAR_TARGET_SDK"] as String? ?: "36").toInt()

android {
    namespace = "in.buildacre.buildacre_crm"
    compileSdk = mortarCompileSdk
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.buildacre.buildacre_crm"
        minSdk = mortarMinSdk
        targetSdk = mortarTargetSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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
