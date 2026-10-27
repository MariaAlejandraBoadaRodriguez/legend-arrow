extends GutTest
## AudioDirector: assets exist, voice limit, retrigger rate limit, mute
## reasons (background + full-screen ad) and buses.

var director: AudioDirector
var now_ms := 0


func _clock() -> int:
	return now_ms


func before_each() -> void:
	now_ms = 1000
	director = AudioDirector.new()
	director.clock = _clock
	add_child_autofree(director)


func after_each() -> void:
	AudioServer.set_bus_mute(0, false)


func test_every_sound_and_creature_motif_is_packaged() -> void:
	for s in AudioDirector.SFX:
		assert_true(ResourceLoader.exists(AudioDirector.DIR + s + ".wav"), s)
	var roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")).creatures
	assert_gt(roster.size(), 0)
	for c in roster:
		assert_true(ResourceLoader.exists(AudioDirector.DIR + "creature_%s.wav" % c.id), c.id)
	var music := load(AudioDirector.DIR + "music_ambient.wav") as AudioStreamWAV
	assert_not_null(music)
	assert_eq(music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "music loops")


func test_players_use_the_settings_buses() -> void:
	var buses := {}
	for child in director.get_children():
		buses[(child as AudioStreamPlayer).bus] = true
	assert_eq(buses.keys().size(), 3)
	for b in ["SFX", "Creature", "Music"]:
		assert_true(buses.has(b), b)
		assert_ne(AudioServer.get_bus_index(b), -1, "bus %s exists" % b)


func test_voice_limit_steals_instead_of_growing() -> void:
	var used := {}
	for i in AudioDirector.VOICES * 3:
		now_ms += 100
		var v := director.play_sfx(["tap", "exit", "blocked"][i % 3])
		assert_not_null(v)
		used[v] = true
	assert_eq(used.size(), AudioDirector.VOICES, "never more than VOICES players")
	assert_eq(director.get_child_count(), AudioDirector.VOICES + 2)


func test_same_sound_retrigger_is_rate_limited() -> void:
	assert_not_null(director.play_sfx("exit"))
	now_ms += AudioDirector.RETRIGGER_MS - 1
	assert_null(director.play_sfx("exit"), "too soon")
	assert_not_null(director.play_sfx("blocked"), "other sounds are not limited")
	now_ms += 1
	assert_not_null(director.play_sfx("exit"), "allowed again after the window")


func test_unknown_sound_is_harmless() -> void:
	assert_null(director.play_sfx("nope"))
	assert_false(director.play_creature("nope"))


func test_mute_reasons_stack() -> void:
	director.set_muted("background", true)
	director.set_muted("ad", true)
	director.set_muted("background", false)
	assert_true(AudioServer.is_bus_mute(0), "ad still showing")
	director.set_muted("ad", false)
	assert_false(AudioServer.is_bus_mute(0))
	assert_false(director.is_muted())


func test_music_starts_once() -> void:
	director.play_music()
	director.play_music()
	assert_true(director.music_playing())
	director.stop_music()
	assert_false(director.music_playing())


func test_every_creature_motif_plays() -> void:
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")).creatures:
		assert_true(director.play_creature(c.id), c.id)
	director.stop_creature()
