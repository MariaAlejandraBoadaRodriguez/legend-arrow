class_name InterstitialPolicy
extends RefCounted
## When an interstitial may appear (spec §16): only between levels after a
## completed level's reward/reveal flow; never on first launch, tutorial,
## failure, back/exit or resume; at least N completed non-tutorial levels
## since the last one and at least M seconds since ANY full-screen ad
## (rewarded included); never for child/unknown audiences in v1.

const CONTEXT_BETWEEN_LEVELS := "between_levels"

var limits: RemoteConfig
var restricted_audience := true
var levels_since_last := 0
var last_fullscreen_at := -INF   # seconds, from the injected clock


func _init(p_limits: RemoteConfig, p_restricted: bool) -> void:
	limits = p_limits
	restricted_audience = p_restricted


func on_level_completed(is_tutorial: bool) -> void:
	if not is_tutorial:
		levels_since_last += 1


func on_fullscreen_ad_shown(now: float, was_interstitial: bool) -> void:
	last_fullscreen_at = now
	if was_interstitial:
		levels_since_last = 0


## Returns "" when allowed, otherwise the reason it is not.
func blocked_reason(now: float, context: String) -> String:
	if restricted_audience:
		return "restricted_audience"
	if not limits.interstitials_enabled:
		return "disabled"
	if context != CONTEXT_BETWEEN_LEVELS:
		return "context"
	if levels_since_last < limits.min_levels_between_interstitials:
		return "level_cap"
	if now - last_fullscreen_at < limits.min_seconds_between_fullscreen:
		return "cooldown"
	return ""


func allowed(now: float, context: String) -> bool:
	return blocked_reason(now, context) == ""
