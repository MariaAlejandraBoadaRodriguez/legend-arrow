class_name AndroidAdProvider
extends AdProvider
## Forwards to the Kotlin plugin singleton "LegendAds"
## (android/plugins/legend_ads). Plugin callbacks arrive on Godot's main
## thread as signals and are re-emitted unchanged.

const SINGLETON := "LegendAds"
const FORWARDED := ["consent_info_updated", "consent_error", "privacy_options_closed", "initialized",
	"rewarded_loaded", "rewarded_load_failed", "rewarded_shown", "rewarded_earned",
	"rewarded_closed", "rewarded_show_failed", "interstitial_loaded",
	"interstitial_load_failed", "interstitial_closed", "interstitial_show_failed"]

var _plugin: Object


func _init() -> void:
	if Engine.has_singleton(SINGLETON):
		_plugin = Engine.get_singleton(SINGLETON)
		for sig in FORWARDED:
			if _plugin.has_signal(sig):
				_plugin.connect(sig, _forward.bind(sig))


## Plugin signals carry 0-2 arguments; the bound signal name comes last.
func _forward(a = null, b = null, c = null) -> void:
	var args := [a, b, c].filter(func(x): return x != null)
	var sig: String = args.pop_back()
	if sig == "consent_info_updated" and typeof(args[0]) == TYPE_STRING:
		args[0] = JSON.parse_string(args[0])  # plugin sends JSON text
	callv("emit_signal", [sig] + args)


func is_available() -> bool:
	return _plugin != null


func configure(config: Dictionary) -> void:
	if _plugin:
		_plugin.configure(JSON.stringify(config))


func request_consent_update() -> void:
	if _plugin:
		_plugin.requestConsentUpdate()
	else:
		super()


func show_privacy_options() -> void:
	if _plugin:
		_plugin.showPrivacyOptions()
	else:
		super()


func initialize() -> void:
	if _plugin:
		_plugin.initializeAds()


func load_rewarded() -> void:
	if _plugin:
		_plugin.loadRewarded()
	else:
		super()


func show_rewarded(presentation_id: String) -> void:
	if _plugin:
		_plugin.showRewarded(presentation_id)
	else:
		super(presentation_id)


func load_interstitial() -> void:
	if _plugin:
		_plugin.loadInterstitial()
	else:
		super()


func show_interstitial() -> void:
	if _plugin:
		_plugin.showInterstitial()
	else:
		super()
