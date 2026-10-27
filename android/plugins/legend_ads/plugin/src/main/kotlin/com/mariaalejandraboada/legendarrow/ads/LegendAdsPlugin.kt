package com.mariaalejandraboada.legendarrow.ads

import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.RequestConfiguration
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import com.mariaalejandraboada.legendarrow.ads.core.AdCodes
import com.mariaalejandraboada.legendarrow.ads.core.AdSettings
import com.mariaalejandraboada.legendarrow.ads.core.ConsentJson
import com.mariaalejandraboada.legendarrow.ads.core.RewardLedger
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Godot Android plugin (v2) "LegendAds": Google UMP consent + Google Mobile
 * Ads rewarded/interstitial, with child/unknown audiences always restricted.
 *
 * Every SDK call runs on the UI thread; every result goes back to GDScript as
 * a signal (AndroidAdProvider re-emits them). No method throws into Godot and
 * nothing here holds references to Godot nodes. The plugin never decides on
 * rewards: it reports the SDK's earned callback once per presentation id and
 * the game grants (and persists) the hint.
 */
class LegendAdsPlugin(godot: Godot) : GodotPlugin(godot) {

    private var settings: AdSettings? = null
    private var consentInformation: ConsentInformation? = null
    private val consentRequested = AtomicBoolean(false)
    private val adsInitialized = AtomicBoolean(false)
    private var rewarded: RewardedAd? = null
    private var interstitial: InterstitialAd? = null
    private val ledger = RewardLedger()

    override fun getPluginName() = "LegendAds"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("consent_info_updated", String::class.java),
        SignalInfo("consent_error", String::class.java),
        SignalInfo("privacy_options_closed"),
        SignalInfo("initialized"),
        SignalInfo("rewarded_loaded"),
        SignalInfo("rewarded_load_failed", String::class.java, String::class.java),
        SignalInfo("rewarded_shown", String::class.java),
        SignalInfo("rewarded_earned", String::class.java),
        SignalInfo("rewarded_closed", String::class.java),
        SignalInfo("rewarded_show_failed", String::class.java, String::class.java),
        SignalInfo("interstitial_loaded"),
        SignalInfo("interstitial_load_failed", String::class.java, String::class.java),
        SignalInfo("interstitial_closed"),
        SignalInfo("interstitial_show_failed", String::class.java),
    )

    /** JSON from AdConfig.to_provider_dict(). Must be called before anything else. */
    @UsedByGodot
    fun configure(json: String) {
        val parsed = try {
            AdSettings.parse(json)
        } catch (e: Exception) {
            Log.w(TAG, "configure: unreadable settings", e)
            null
        }
        val problems = parsed?.errors() ?: listOf("unreadable settings")
        if (problems.isNotEmpty()) {
            Log.w(TAG, "configure: ads disabled: $problems")
            settings = null
            return
        }
        settings = parsed
        val s = parsed!!
        val rc = RequestConfiguration.Builder()
            .setTagForChildDirectedTreatment(
                if (s.childDirected) RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE
                else RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_FALSE
            )
            .setTagForUnderAgeOfConsent(
                if (s.underAgeOfConsent) RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE
                else RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_FALSE
            )
            .setMaxAdContentRating(
                when (s.maxAdContentRating) {
                    "PG" -> RequestConfiguration.MAX_AD_CONTENT_RATING_PG
                    "T" -> RequestConfiguration.MAX_AD_CONTENT_RATING_T
                    "MA" -> RequestConfiguration.MAX_AD_CONTENT_RATING_MA
                    else -> RequestConfiguration.MAX_AD_CONTENT_RATING_G
                }
            )
            .build()
        MobileAds.setRequestConfiguration(rc)
    }

    /** UMP: one request per launch; shows the form only if required. */
    @UsedByGodot
    fun requestConsentUpdate() {
        val s = settings
        val act = activity
        if (s == null || act == null) {
            emitSignal("consent_error", "not configured")
            return
        }
        if (!consentRequested.compareAndSet(false, true)) return
        act.runOnUiThread {
            val info = UserMessagingPlatform.getConsentInformation(act)
            consentInformation = info
            val params = ConsentRequestParameters.Builder()
                .setTagForUnderAgeOfConsent(s.underAgeOfConsent)
                .build()
            info.requestConsentInfoUpdate(act, params, {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(act) { formError ->
                    if (formError != null) Log.i(TAG, "consent form: ${formError.message}")
                    emitConsent()
                }
            }, { error ->
                consentRequested.set(false) // allow a later retry
                emitSignal("consent_error", error.message)
            })
        }
    }

    @UsedByGodot
    fun showPrivacyOptions() {
        val act = activity ?: return
        act.runOnUiThread {
            UserMessagingPlatform.showPrivacyOptionsForm(act) { formError ->
                if (formError != null) Log.i(TAG, "privacy options: ${formError.message}")
                emitConsent()
                emitSignal("privacy_options_closed")
            }
        }
    }

    @UsedByGodot
    fun initializeAds() {
        val act = activity ?: return
        if (settings == null || consentInformation?.canRequestAds() != true) return
        if (!adsInitialized.compareAndSet(false, true)) return
        Thread {
            MobileAds.initialize(act) { emitSignal("initialized") }
        }.start()
    }

    @UsedByGodot
    fun loadRewarded() {
        val s = settings
        val act = activity
        if (s == null || act == null || !canRequest()) {
            emitSignal("rewarded_load_failed", "error", "ads not permitted")
            return
        }
        act.runOnUiThread {
            RewardedAd.load(act, s.rewardedUnit, AdRequest.Builder().build(), object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewarded = ad
                    emitSignal("rewarded_loaded")
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    rewarded = null
                    emitSignal("rewarded_load_failed", AdCodes.loadError(error.code), error.message)
                }
            })
        }
    }

    @UsedByGodot
    fun showRewarded(presentationId: String) {
        val act = activity
        val ad = rewarded
        if (act == null || ad == null) {
            emitSignal("rewarded_show_failed", presentationId, "not loaded")
            return
        }
        rewarded = null
        act.runOnUiThread {
            ad.fullScreenContentCallback = object : FullScreenContentCallback() {
                override fun onAdShowedFullScreenContent() {
                    emitSignal("rewarded_shown", presentationId)
                }

                override fun onAdDismissedFullScreenContent() {
                    if (ledger.markClosed(presentationId)) emitSignal("rewarded_closed", presentationId)
                }

                override fun onAdFailedToShowFullScreenContent(error: AdError) {
                    emitSignal("rewarded_show_failed", presentationId, error.message)
                }
            }
            ad.show(act) {
                if (ledger.markEarned(presentationId)) emitSignal("rewarded_earned", presentationId)
            }
        }
    }

    @UsedByGodot
    fun loadInterstitial() {
        val s = settings
        val act = activity
        if (s == null || act == null || !canRequest() || !s.interstitialsAllowed) {
            emitSignal("interstitial_load_failed", "error", "interstitials not permitted")
            return
        }
        act.runOnUiThread {
            InterstitialAd.load(act, s.interstitialUnit, AdRequest.Builder().build(), object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitial = ad
                    emitSignal("interstitial_loaded")
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    interstitial = null
                    emitSignal("interstitial_load_failed", AdCodes.loadError(error.code), error.message)
                }
            })
        }
    }

    @UsedByGodot
    fun showInterstitial() {
        val act = activity
        val ad = interstitial
        if (act == null || ad == null || settings?.interstitialsAllowed != true) {
            emitSignal("interstitial_show_failed", "not loaded")
            return
        }
        interstitial = null
        act.runOnUiThread {
            ad.fullScreenContentCallback = object : FullScreenContentCallback() {
                override fun onAdDismissedFullScreenContent() {
                    emitSignal("interstitial_closed")
                }

                override fun onAdFailedToShowFullScreenContent(error: AdError) {
                    emitSignal("interstitial_show_failed", error.message)
                }
            }
            ad.show(act)
        }
    }

    private fun canRequest(): Boolean = consentInformation?.canRequestAds() == true

    private fun emitConsent() {
        val info = consentInformation ?: return
        val privacyRequired = info.privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
        emitSignal("consent_info_updated", ConsentJson.build(info.consentStatus, info.canRequestAds(), privacyRequired))
    }

    companion object {
        private const val TAG = "LegendAds"
    }
}
