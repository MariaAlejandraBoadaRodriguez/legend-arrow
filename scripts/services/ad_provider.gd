class_name AdProvider
extends RefCounted
## Boundary between the game and an ad SDK. Implementations: MockAdProvider
## (desktop, tests, CI), AndroidAdProvider (Kotlin plugin "LegendAds") and the
## base class itself, which is "unavailable" and never emits rewards.
## Signals carry plain data only; nothing here touches scene nodes.

## info: {status: String, can_request_ads: bool, privacy_options_required: bool}
signal consent_info_updated(info: Dictionary)
signal consent_error(message: String)
signal privacy_options_closed
signal initialized
signal rewarded_loaded
signal rewarded_load_failed(code: String, message: String)
signal rewarded_shown(presentation_id: String)
signal rewarded_earned(presentation_id: String)
signal rewarded_closed(presentation_id: String)
signal rewarded_show_failed(presentation_id: String, message: String)
signal interstitial_loaded
signal interstitial_load_failed(code: String, message: String)
signal interstitial_closed
signal interstitial_show_failed(message: String)


func is_available() -> bool:
	return false


func configure(_config: Dictionary) -> void:
	pass


func request_consent_update() -> void:
	consent_error.emit("ads unavailable")


func show_privacy_options() -> void:
	privacy_options_closed.emit()


func initialize() -> void:
	pass


func load_rewarded() -> void:
	rewarded_load_failed.emit("unavailable", "ads unavailable")


func show_rewarded(presentation_id: String) -> void:
	rewarded_show_failed.emit(presentation_id, "ads unavailable")


func load_interstitial() -> void:
	interstitial_load_failed.emit("unavailable", "ads unavailable")


func show_interstitial() -> void:
	interstitial_show_failed.emit("ads unavailable")
