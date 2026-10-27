// Versions match Godot 4.7.2's Android build template (android_source.zip
// config.gradle): AGP 8.6.1, Kotlin 2.1.21, Gradle 8.11.1.
//
// Both Gradle plugins must live on the ROOT classpath: the Kotlin plugin's
// Android support needs AGP classes from the same classloader. AGP is left
// out with -PcoreOnly=true so the core module still builds where Google Maven
// is unreachable.
buildscript {
    val coreOnly = gradle.startParameter.projectProperties["coreOnly"] == "true"
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.21")
        if (!coreOnly) {
            classpath("com.android.tools.build:gradle:8.6.1")
        }
    }
}
