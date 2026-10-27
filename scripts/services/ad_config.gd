class_name AdConfig
extends RefCounted
## Ad identifiers and audience declaration. Development and CI always use
## Google's official test IDs. Real IDs are owner-supplied at release time in
## res://ads_release.json (not committed; see docs/ADS_AND_PRIVACY.md).

## Google's published sample IDs (safe to commit; they never serve live ads).
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_PUBLISHER := "ca-app-pub-3940256099942544"
const RELEASE_FILE := "res://ads_release.json"

## The app is for a mixed audience. With no age screen, every player gets the
## restrictive child/unknown treatment (spec §17).
const AUDIENCES := ["child", "unknown", "adult"]

var app_id := TEST_APP_ID
var rewarded_unit := TEST_REWARDED_ID
var interstitial_unit := TEST_INTERSTITIAL_ID
var audience := "unknown"
var consent_configured := true   # UMP message set up in the AdMob console
var is_test := true


static func test_config() -> AdConfig:
	return AdConfig.new()


## Release builds read the owner's file; anything else uses test IDs.
static func load_for_build(debug_build: bool) -> AdConfig:
	if debug_build or not FileAccess.file_exists(RELEASE_FILE):
		return test_config()
	var d = JSON.parse_string(FileAccess.get_file_as_string(RELEASE_FILE))
	return from_dict(d if typeof(d) == TYPE_DICTIONARY else {})


static func from_dict(d: Dictionary) -> AdConfig:
	var c := AdConfig.new()
	c.app_id = str(d.get("app_id", ""))
	c.rewarded_unit = str(d.get("rewarded_unit", ""))
	c.interstitial_unit = str(d.get("interstitial_unit", ""))
	c.audience = str(d.get("audience", "unknown"))
	c.consent_configured = bool(d.get("consent_configured", false))
	c.is_test = false
	return c


## Problems that must block ad requests in a release build. Empty = OK.
func release_errors() -> Array[String]:
	var errors: Array[String] = []
	for pair in [["app_id", app_id], ["rewarded_unit", rewarded_unit], ["interstitial_unit", interstitial_unit]]:
		var v: String = pair[1]
		if v.is_empty():
			errors.append("%s is missing" % pair[0])
		elif v.begins_with(TEST_PUBLISHER):
			errors.append("%s is a Google test ID" % pair[0])
		elif not v.begins_with("ca-app-pub-"):
			errors.append("%s is not an AdMob ID" % pair[0])
	if not app_id.contains("~"):
		errors.append("app_id must be an app ID (contains '~')")
	if not AUDIENCES.has(audience):
		errors.append("audience must be one of %s" % ", ".join(AUDIENCES))
	if not consent_configured:
		errors.append("consent (UMP) message is not configured")
	return errors


## Child/unknown players get child-directed, under-age, G-rated requests and
## no interstitials in v1.
func restricted() -> bool:
	return audience != "adult"


func to_provider_dict() -> Dictionary:
	return {
		"app_id": app_id,
		"rewarded_unit": rewarded_unit,
		"interstitial_unit": interstitial_unit,
		"audience": audience,
		"child_directed": restricted(),
		"under_age_of_consent": restricted(),
		"max_ad_content_rating": "G" if restricted() else "PG",
		"test": is_test,
	}
