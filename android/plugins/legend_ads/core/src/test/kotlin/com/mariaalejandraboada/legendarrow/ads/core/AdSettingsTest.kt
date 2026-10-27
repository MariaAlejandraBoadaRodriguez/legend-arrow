package com.mariaalejandraboada.legendarrow.ads.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdSettingsTest {
    private val testUnits = """"rewarded_unit":"ca-app-pub-3940256099942544/5224354917","interstitial_unit":"ca-app-pub-3940256099942544/1033173712""""

    @Test fun unknownAudienceIsRestrictedEvenIfFlagsSayOtherwise() {
        val s = AdSettings.parse("""{"audience":"unknown","child_directed":false,"under_age_of_consent":false,"max_ad_content_rating":"MA",$testUnits,"test":true}""")
        assertTrue(s.restricted)
        assertTrue(s.childDirected)
        assertTrue(s.underAgeOfConsent)
        assertEquals("G", s.maxAdContentRating)
        assertFalse(s.interstitialsAllowed)
    }

    @Test fun childAudienceIsRestricted() {
        val s = AdSettings.parse("""{"audience":"child",$testUnits,"test":true}""")
        assertTrue(s.childDirected && s.underAgeOfConsent)
        assertEquals("G", s.maxAdContentRating)
    }

    @Test fun missingAudienceDefaultsToUnknown() {
        val s = AdSettings.parse("""{$testUnits,"test":true}""")
        assertEquals("unknown", s.audience)
        assertTrue(s.restricted)
    }

    @Test fun adultAudienceUsesProvidedRating() {
        val s = AdSettings.parse("""{"audience":"adult","child_directed":false,"under_age_of_consent":false,"max_ad_content_rating":"PG",$testUnits,"test":true}""")
        assertFalse(s.restricted)
        assertFalse(s.childDirected)
        assertEquals("PG", s.maxAdContentRating)
        assertTrue(s.interstitialsAllowed)
    }

    @Test fun invalidRatingFallsBackToG() {
        val s = AdSettings.parse("""{"audience":"adult","max_ad_content_rating":"XXX",$testUnits,"test":true}""")
        assertEquals("G", s.maxAdContentRating)
    }

    @Test fun testIdsAreValidOnlyInTestConfig() {
        assertTrue(AdSettings.parse("""{"audience":"unknown",$testUnits,"test":true}""").errors().isEmpty())
        val release = AdSettings.parse("""{"audience":"unknown",$testUnits,"test":false}""")
        assertEquals(2, release.errors().count { it.contains("test id") })
    }

    @Test fun malformedUnitIdsAreRejected() {
        val s = AdSettings.parse("""{"audience":"unknown","rewarded_unit":"","interstitial_unit":"abc","test":true}""")
        assertEquals(2, s.errors().size)
    }

    @Test fun unknownAudienceNameIsRejectedButStillRestricted() {
        val s = AdSettings.parse("""{"audience":"teens",$testUnits,"test":true}""")
        assertTrue(s.restricted)
        assertTrue(s.errors().any { it.contains("audience") })
    }
}
