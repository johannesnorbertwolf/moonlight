import java.util.Properties

plugins {
    id("com.android.application")
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun quoted(key: String): String =
    "\"" + (localProps.getProperty(key) ?: "").replace("\"", "\\\"") + "\""

android {
    namespace = "nl.moonlight.measure"
    compileSdk = 35

    defaultConfig {
        applicationId = "nl.moonlight.measure"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "0.1-test"

        buildConfigField("String", "SUPABASE_URL", quoted("moonlight.supabaseUrl"))
        buildConfigField("String", "SUPABASE_KEY", quoted("moonlight.supabaseKey"))
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Test build: sign release with the debug key so the APK can be shared directly.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}
