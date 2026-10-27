package com.mariaalejandraboada.legendarrow.ads.core

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RewardLedgerTest {
    @Test fun earnedOncePerPresentation() {
        val l = RewardLedger()
        assertTrue(l.markEarned("rw-1"))
        assertFalse(l.markEarned("rw-1"))
        assertTrue(l.markEarned("rw-2"))
    }

    @Test fun closedOncePerPresentation() {
        val l = RewardLedger()
        assertTrue(l.markClosed("rw-1"))
        assertFalse(l.markClosed("rw-1"))
    }

    @Test fun emptyIdsAreIgnored() {
        val l = RewardLedger()
        assertFalse(l.markEarned(""))
        assertFalse(l.markClosed(""))
    }

    @Test fun lateRewardAfterCloseStillCountsOnce() {
        val l = RewardLedger()
        assertTrue(l.markClosed("rw-9"))
        assertTrue(l.markEarned("rw-9"))
        assertFalse(l.markEarned("rw-9"))
    }
}
