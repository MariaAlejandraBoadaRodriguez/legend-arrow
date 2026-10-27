package com.mariaalejandraboada.legendarrow.ads.core

/**
 * Forwards each callback at most once per presentation id. The game also
 * dedupes (persisted receipts); this keeps SDK quirks from even reaching it.
 */
class RewardLedger {
    private val earned = HashSet<String>()
    private val closed = HashSet<String>()

    /** True the first time a reward for this presentation is reported. */
    fun markEarned(presentationId: String): Boolean =
        presentationId.isNotEmpty() && earned.add(presentationId)

    /** True the first time this presentation closes. */
    fun markClosed(presentationId: String): Boolean =
        presentationId.isNotEmpty() && closed.add(presentationId)
}
