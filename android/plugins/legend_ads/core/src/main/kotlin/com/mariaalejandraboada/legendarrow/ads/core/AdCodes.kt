package com.mariaalejandraboada.legendarrow.ads.core

/** Maps SDK numeric codes to the names the game understands. */
object AdCodes {
    // com.google.android.gms.ads.AdRequest error codes.
    const val ERROR_CODE_INTERNAL_ERROR = 0
    const val ERROR_CODE_INVALID_REQUEST = 1
    const val ERROR_CODE_NETWORK_ERROR = 2
    const val ERROR_CODE_NO_FILL = 3

    // com.google.android.ump.ConsentInformation.ConsentStatus values.
    const val CONSENT_UNKNOWN = 0
    const val CONSENT_NOT_REQUIRED = 1
    const val CONSENT_REQUIRED = 2
    const val CONSENT_OBTAINED = 3

    fun loadError(code: Int): String = when (code) {
        ERROR_CODE_NETWORK_ERROR -> "network"
        ERROR_CODE_NO_FILL -> "no_fill"
        else -> "error"
    }

    fun consentStatus(status: Int): String = when (status) {
        CONSENT_NOT_REQUIRED -> "not_required"
        CONSENT_REQUIRED -> "required"
        CONSENT_OBTAINED -> "obtained"
        else -> "unknown"
    }
}
