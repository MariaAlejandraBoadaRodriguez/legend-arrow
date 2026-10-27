class_name RemoteConfig
extends RefCounted
## Optional configuration hook (spec §17). There is no server in v1: values
## come from local defaults. Any override can only REDUCE ad pressure or keep
## the hard-coded limits; it can never enable more ads or run code.

const HARD_MIN_LEVELS_BETWEEN_INTERSTITIALS := 5
const HARD_MIN_SECONDS_BETWEEN_FULLSCREEN := 180
const MAX_LEVELS_BETWEEN_INTERSTITIALS := 1000
const MAX_SECONDS_BETWEEN_FULLSCREEN := 86400
const RETRY_COOLDOWN_SECONDS := 5.0

var rewarded_enabled := true
var interstitials_enabled := true
var min_levels_between_interstitials := HARD_MIN_LEVELS_BETWEEN_INTERSTITIALS
var min_seconds_between_fullscreen := HARD_MIN_SECONDS_BETWEEN_FULLSCREEN


## Applies overrides, clamped to safe ranges. Unknown keys are ignored.
## Returns the keys that were accepted.
func apply(overrides: Dictionary) -> Array[String]:
	var accepted: Array[String] = []
	if overrides.get("rewarded_enabled") == false:
		rewarded_enabled = false
		accepted.append("rewarded_enabled")
	if overrides.get("interstitials_enabled") == false:
		interstitials_enabled = false
		accepted.append("interstitials_enabled")
	if overrides.has("min_levels_between_interstitials"):
		min_levels_between_interstitials = clampi(int(overrides.min_levels_between_interstitials),
			HARD_MIN_LEVELS_BETWEEN_INTERSTITIALS, MAX_LEVELS_BETWEEN_INTERSTITIALS)
		accepted.append("min_levels_between_interstitials")
	if overrides.has("min_seconds_between_fullscreen"):
		min_seconds_between_fullscreen = clampi(int(overrides.min_seconds_between_fullscreen),
			HARD_MIN_SECONDS_BETWEEN_FULLSCREEN, MAX_SECONDS_BETWEEN_FULLSCREEN)
		accepted.append("min_seconds_between_fullscreen")
	return accepted
