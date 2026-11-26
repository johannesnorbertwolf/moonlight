import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
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
        versionCode = 2
        versionName = "0.2"

        buildConfigField("String", "SUPABASE_URL", quoted("moonlight.supabaseUrl"))
        buildConfigField("String", "SUPABASE_KEY", quoted("moonlight.supabaseKey"))
    }

    buildFeatures {
        buildConfig = true
        compose = true
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
    implementation(platform("androidx.compose:compose-bom:2025.06.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
