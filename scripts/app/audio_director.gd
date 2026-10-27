class_name AudioDirector
extends Node
## Plays all game audio on the Music / SFX / Creature buses (volumes come from
## settings via Game.apply_settings). SFX share a small voice pool: when every
## voice is busy the oldest is stolen, and the same sound retriggered within
## RETRIGGER_MS is dropped so fast taps never stack into noise. Master is muted
## while any reason is active (app in background, full-screen ad).

const SFX := ["tap", "exit", "blocked", "hint", "complete", "ui"]
const VOICES := 6
const RETRIGGER_MS := 45
const DIR := "res://assets/audio/"

var clock: Callable = Callable()   # tests inject a fake millisecond clock
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}  # sound -> ms
var _music: AudioStreamPlayer
var _creature: AudioStreamPlayer
var _mute_reasons: Dictionary = {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.name = "Sfx%d" % i
		add_child(p)
		_voices.append(p)
	_creature = AudioStreamPlayer.new()
	_creature.bus = "Creature"
	_creature.name = "Creature"
	add_child(_creature)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.name = "Music"
	_music.volume_db = -4.0
	add_child(_music)


func _now() -> int:
	return int(clock.call()) if clock.is_valid() else Time.get_ticks_msec()


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


## Returns the voice used, or null when the sound is unknown or rate-limited.
func play_sfx(sound: String) -> AudioStreamPlayer:
	var stream := _stream(sound)
	if stream == null:
		push_warning("AudioDirector: unknown sound %s" % sound)
		return null
	var now := _now()
	if _last_played.has(sound) and now - int(_last_played[sound]) < RETRIGGER_MS:
		return null
	_last_played[sound] = now
	var voice: AudioStreamPlayer = null
	for i in VOICES:
		var p := _voices[(_next + i) % VOICES]
		if not p.playing:
			voice = p
			_next = (_next + i + 1) % VOICES
			break
	if voice == null:  # steal the oldest (round-robin order)
		voice = _voices[_next]
		_next = (_next + 1) % VOICES
	voice.stream = stream
	voice.play()
	return voice


func play_creature(creature_id: String) -> bool:
	var stream := _stream("creature_" + creature_id)
	if stream == null:
		return false
	_creature.stream = stream
	_creature.play()
	return true


func stop_creature() -> void:
	_creature.stop()


func play_music() -> void:
	if _music.playing:
		return
	var stream := _stream("music_ambient")  # loops via its .import (loop_mode=2)
	if stream == null:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func music_playing() -> bool:
	return _music.playing


func busy_voices() -> int:
	var n := 0
	for p in _voices:
		n += 1 if p.playing else 0
	return n


func set_muted(reason: String, muted: bool) -> void:
	if muted:
		_mute_reasons[reason] = true
	else:
		_mute_reasons.erase(reason)
	AudioServer.set_bus_mute(0, not _mute_reasons.is_empty())


func is_muted() -> bool:
	return not _mute_reasons.is_empty()
