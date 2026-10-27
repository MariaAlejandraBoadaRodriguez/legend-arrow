class_name ConsentService
extends RefCounted
## Wraps the provider's UMP flow (spec §17). Requests a consent update once
## per launch, never twice concurrently, and reports whether ads may be
## requested. Refusal, errors and offline only disable ads; gameplay never waits.

signal changed

enum State { NOT_REQUESTED, REQUESTING, READY, ERROR }

var provider: AdProvider
var state := State.NOT_REQUESTED
var status := "unknown"
var can_request_ads := false
var privacy_options_required := false
var last_error := ""


func _init(p_provider: AdProvider) -> void:
	provider = p_provider
	provider.consent_info_updated.connect(_on_info)
	provider.consent_error.connect(_on_error)


## Safe to call repeatedly; only the first call (or a retry after an error)
## reaches the SDK.
func request_update() -> bool:
	if state == State.REQUESTING or state == State.READY:
		return false
	if not provider.is_available():
		_on_error("ads unavailable")
		return false
	state = State.REQUESTING
	provider.request_consent_update()
	return true


func show_privacy_options() -> bool:
	if not privacy_options_required:
		return false
	provider.show_privacy_options()
	return true


func _on_info(info: Dictionary) -> void:
	state = State.READY
	status = str(info.get("status", "unknown"))
	can_request_ads = bool(info.get("can_request_ads", false))
	privacy_options_required = bool(info.get("privacy_options_required", false))
	changed.emit()


func _on_error(message: String) -> void:
	state = State.ERROR
	last_error = message
	# Keep whatever the SDK last told us; an error never grants permission.
	changed.emit()
