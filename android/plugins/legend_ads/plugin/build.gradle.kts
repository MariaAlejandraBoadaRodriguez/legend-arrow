plugins {
    id("com.android.library") version "8.6.1"
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.mariaalejandraboada.legendarrow.ads"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    // The core sources are compiled into this AAR (a project dependency would
    // not be bundled into the AAR that Godot copies into the app).
    sourceSets["main"].java.srcDir("../core/src/main/kotlin")
    sourceSets["test"].java.srcDir("../core/src/test/kotlin")

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    lint {
        abortOnError = true
        checkDependencies = false
        // New SDK versions appear constantly; versions are pinned on purpose.
        disable += setOf("GradleDependency", "NewerVersionAvailable", "AndroidGradlePluginVersion")
        xmlReport = true
        htmlReport = true
    }
    testOptions {
        unitTests.isReturnDefaultValues = false
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.7.2.stable")
    implementation("com.google.android.gms:play-services-ads:24.4.0")
    implementation("com.google.android.ump:user-messaging-platform:3.2.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
