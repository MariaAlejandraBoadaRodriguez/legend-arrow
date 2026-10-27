package com.mariaalejandraboada.legendarrow.ads.core

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdCodesTest {
    @Test fun loadErrorsMapToGameCodes() {
        assertEquals("network", AdCodes.loadError(AdCodes.ERROR_CODE_NETWORK_ERROR))
        assertEquals("no_fill", AdCodes.loadError(AdCodes.ERROR_CODE_NO_FILL))
        assertEquals("error", AdCodes.loadError(AdCodes.ERROR_CODE_INTERNAL_ERROR))
        assertEquals("error", AdCodes.loadError(99))
    }

    @Test fun consentStatusesMap() {
        assertEquals("unknown", AdCodes.consentStatus(AdCodes.CONSENT_UNKNOWN))
        assertEquals("not_required", AdCodes.consentStatus(AdCodes.CONSENT_NOT_REQUIRED))
        assertEquals("required", AdCodes.consentStatus(AdCodes.CONSENT_REQUIRED))
        assertEquals("obtained", AdCodes.consentStatus(AdCodes.CONSENT_OBTAINED))
        assertEquals("unknown", AdCodes.consentStatus(-1))
    }

    @Test fun consentJsonCarriesOnlyThreeFields() {
        val o = JSONObject(ConsentJson.build(AdCodes.CONSENT_REQUIRED, false, true))
        assertEquals(setOf("status", "can_request_ads", "privacy_options_required"), o.keys().asSequence().toSet())
        assertEquals("required", o.getString("status"))
        assertFalse(o.getBoolean("can_request_ads"))
        assertTrue(o.getBoolean("privacy_options_required"))
    }
}
