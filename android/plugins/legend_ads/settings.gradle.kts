// Legend Arrow ads plugin (Godot Android plugin v2).
// `core` holds SDK-independent logic and builds from Maven Central alone, so
// it can be tested anywhere. `plugin` is the Android library (needs Google
// Maven); skip it with -PcoreOnly=true where Google Maven is unreachable.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "legend_ads"
include(":core")
if (providers.gradleProperty("coreOnly").orNull != "true") {
    include(":plugin")
}
