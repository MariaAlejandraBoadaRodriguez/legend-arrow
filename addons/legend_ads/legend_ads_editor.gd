@tool
extends EditorPlugin
## Adds the LegendAds AAR, its Maven dependencies and manifest entries to
## Android Gradle exports. The AAR is built from android/plugins/legend_ads
## (scripts/build_ads_plugin.sh) into addons/legend_ads/bin/ and is not
## committed.

var _export: LegendAdsExport


func _enter_tree() -> void:
	_export = LegendAdsExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class LegendAdsExport extends EditorExportPlugin:
	const AAR := "legend_ads/bin/legend_ads-release.aar"
	const DEPENDENCIES := [
		"com.google.android.gms:play-services-ads:24.4.0",
		"com.google.android.ump:user-messaging-platform:3.2.0",
	]

	func _get_name() -> String:
		return "LegendAds"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(DEPENDENCIES)

	## The ads SDK needs the app id in the manifest. Debug exports always use
	## Google's test app id; release exports use the owner's ads_release.json
	## and fail loudly if it is missing or invalid.
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
		var config := AdConfig.load_for_build(debug)
		if not debug and not config.release_errors().is_empty():
			# CI rehearsal AABs (never uploaded) keep Google's test app id so the
			# SDK starts; the release build still refuses every ad request.
			if OS.get_environment("LEGEND_RELEASE_REHEARSAL") == "1":
				print("LegendAds: release REHEARSAL export, no ads_release.json: ads stay disabled")
			else:
				push_error("LegendAds: release export without valid ads_release.json: %s" % str(config.release_errors()))
		return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>' % config.app_id

	## Mixed audience with child/unknown treatment: strip the advertising-ID
	## and Privacy Sandbox (ad id, attribution, topics) permissions the ads SDK
	## merges in (Families policy; spec §15, §17). WorkManager's WAKE_LOCK and
	## FOREGROUND_SERVICE stay; they carry no identifiers.
	const REMOVED_PERMISSIONS := [
		"com.google.android.gms.permission.AD_ID",
		"android.permission.ACCESS_ADSERVICES_AD_ID",
		"android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
		"android.permission.ACCESS_ADSERVICES_TOPICS",
	]

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var lines: PackedStringArray = []
		for p in REMOVED_PERMISSIONS:
			lines.append('<uses-permission android:name="%s" tools:node="remove"/>' % p)
		return "\n".join(lines)
