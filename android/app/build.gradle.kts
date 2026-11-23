import java.io.FileInputStream
import java.util.Properties

plugins {
  id("com.android.application")
  id("kotlin-android")
  id("dev.flutter.flutter-gradle-plugin")
  id("org.jetbrains.kotlin.plugin.compose")
}

// Opt-in personal builds can coexist with the upstream application.
val personalBuild = providers.gradleProperty("flowPersonalBuild")
  .orElse(providers.gradleProperty("FLOWPERSONALBUILD")).orNull == "true"

android {
  namespace = "mn.flow.flow"
  compileSdk = 36
  ndkVersion = "28.2.13676358"

  buildFeatures {
    compose = true
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11

    isCoreLibraryDesugaringEnabled = true
  }

  kotlinOptions {
    jvmTarget = JavaVersion.VERSION_11.toString()
  }

  defaultConfig {
    applicationId = if (personalBuild) "mn.flow.flow.personal" else "mn.flow.flow"
    manifestPlaceholders["appLabel"] = if (personalBuild) "Flow 个人版" else "Flow"
    minSdk = flutter.minSdkVersion
    targetSdk = 36
    versionCode = flutter.versionCode
    versionName = flutter.versionName + if (personalBuild) "-personal.6" else ""
  }

  val keystorePropertiesFile = rootProject.file(
    if (personalBuild) "personal-key.properties" else "key.properties"
  )
  val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
      load(FileInputStream(keystorePropertiesFile))
    }
  }

  signingConfigs {
    create("release") {
      keyAlias = keystoreProperties["keyAlias"] as? String
      keyPassword = keystoreProperties["keyPassword"] as? String
      storeFile = file(keystoreProperties["storeFile"] as? String ?: ".")
      storePassword = keystoreProperties["storePassword"] as? String
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

dependencies {
  implementation("androidx.window:window:1.5.0")
  implementation("androidx.window:window-java:1.5.0")

  implementation("androidx.glance:glance-appwidget:1.1.1")
  implementation("androidx.glance:glance-material3:1.1.1")
  implementation("androidx.glance:glance-preview:1.1.1")
  implementation("androidx.compose.foundation:foundation-layout:1.9.4")

  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
  debugImplementation("androidx.glance:glance-appwidget-preview:1.1.1")
}
