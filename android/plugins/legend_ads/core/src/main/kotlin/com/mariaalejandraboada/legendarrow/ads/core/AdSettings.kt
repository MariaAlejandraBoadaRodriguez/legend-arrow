package com.mariaalejandraboada.legendarrow.ads.core

import org.json.JSONObject

/**
 * Ad settings sent by the game (AdConfig.to_provider_dict() as JSON).
 * Child and unknown audiences always get child-directed, under-age, G-rated
 * requests, whatever the flags say: the safe treatment cannot be switched off
 * by a malformed or tampered config.
 */
data class AdSettings(
    val audience: String,
    val childDirected: Boolean,
    val underAgeOfConsent: Boolean,
    val maxAdContentRating: String,
    val rewardedUnit: String,
    val interstitialUnit: String,
    val test: Boolean,
) {
    val restricted: Boolean get() = audience != "adult"

    /** Interstitials are disabled for child/unknown audiences in v1. */
    val interstitialsAllowed: Boolean get() = !restricted

    /** Problems that must stop all ad requests. Empty means usable. */
    fun errors(): List<String> {
        val out = mutableListOf<String>()
        for ((name, id) in listOf("rewarded_unit" to rewardedUnit, "interstitial_unit" to interstitialUnit)) {
            if (!id.startsWith("ca-app-pub-")) out += "$name is not an AdMob unit id"
            if (!test && id.startsWith(TEST_PUBLISHER)) out += "$name is a test id in a non-test config"
        }
        if (audience !in AUDIENCES) out += "unknown audience '$audience'"
        return out
    }

    companion object {
        const val TEST_PUBLISHER = "ca-app-pub-3940256099942544"
        val AUDIENCES = setOf("child", "unknown", "adult")
        val RATINGS = setOf("G", "PG", "T", "MA")

        fun parse(json: String): AdSettings {
            val o = JSONObject(json)
            val audience = o.optString("audience", "unknown").ifEmpty { "unknown" }
            val restricted = audience != "adult"
            val rating = o.optString("max_ad_content_rating", "G").takeIf { it in RATINGS } ?: "G"
            return AdSettings(
                audience = audience,
                childDirected = restricted || o.optBoolean("child_directed", true),
                underAgeOfConsent = restricted || o.optBoolean("under_age_of_consent", true),
                maxAdContentRating = if (restricted) "G" else rating,
                rewardedUnit = o.optString("rewarded_unit", ""),
                interstitialUnit = o.optString("interstitial_unit", ""),
                test = o.optBoolean("test", false),
            )
        }
    }
}
