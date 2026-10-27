package com.mariaalejandraboada.legendarrow.ads.core

import org.json.JSONObject

/** Payload of the `consent_info_updated` signal. No identifiers inside. */
object ConsentJson {
    fun build(status: Int, canRequestAds: Boolean, privacyOptionsRequired: Boolean): String =
        JSONObject()
            .put("status", AdCodes.consentStatus(status))
            .put("can_request_ads", canRequestAds)
            .put("privacy_options_required", privacyOptionsRequired)
            .toString()
}
