extends Node
## Sound effects and music.
##
## - `play_sfx(id)` plays `<sfx_root>/<id>.wav` or `.ogg` when that resource exists
##   (drop a file into `res://assets/sfx/` to replace a sound), else the sound
##   synthesized from `content/sfx.json` by `SfxSynth`. Streams are cached per id.
##   It uses a pool of `SFX_VOICES` players on the `SFX` bus, so sounds can overlap.
##   An unknown id warns once and plays nothing.
## - `play_music(id, fade)` crossfades to `<music_root>/<id>.ogg` or `.wav` on the
##   `Music` bus, using two players, and `stop_music(fade)` fades it out. A track
##   restarts when it ends, so it loops even if it wasn't imported with looping. An
##   unknown id gives a warning and changes nothing.
##
## Mute and volume are bus settings, applied by the `Settings` autoload.
##
## Registered as the `Audio` autoload after `Content`, whose sfx data it reads; it
## synthesizes every sound on startup so the first play doesn't stall. Tests can make
## their own instance (`preload("res://autoload/audio.gd").new()`, add it to the tree
## to play, free it afterwards), point `sfx_root` or `music_root` at a fixture folder,
## or set `content` to another `Content` instance.

const _SfxSynth := preload("res://core/sfx_synth.gd")

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const SFX_VOICES := 6
const DEFAULT_SFX_ROOT := "res://assets/sfx"
const DEFAULT_MUSIC_ROOT := "res://assets/music"
## Override file extensions, in lookup order.
const SFX_EXTENSIONS: PackedStringArray = ["wav", "ogg"]
const MUSIC_EXTENSIONS: PackedStringArray = ["ogg", "wav"]
## The default crossfade, in seconds.
const DEFAULT_FADE := 0.5

## Where override sound effect files are looked up.
var sfx_root: String = DEFAULT_SFX_ROOT:
	set(value):
		sfx_root = value.trim_suffix("/")
		clear_cache()
## Where music tracks are looked up.
var music_root: String = DEFAULT_MUSIC_ROOT:
	set(value):
		music_root = value.trim_suffix("/")
## The Content node to read sfx.json from; null means the `Content` autoload.
var content: Node = null:
	set(value):
		content = value
		clear_cache()

var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[String, bool] = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
var _music_id := ""
var _music_tween: Tween = null


func _init() -> void:
	# Keep playing and fading while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS
		player.finished.connect(_on_music_finished.bind(player))
		add_child(player)
		_music_players.append(player)


func _ready() -> void:
	preload_sfx()


# --- sound effects ---------------------------------------------------------------

## Plays a sound effect on a free voice (or the oldest one when all are busy), at
## `pitch_scale` (1.0 = as authored; round end steps it up per star). Returns false,
## with a one-time warning, for an unknown id.
func play_sfx(sound_id: String, pitch_scale: float = 1.0) -> bool:
	var stream := sfx_stream(sound_id)
	if stream == null:
		if not _warned.has(sound_id):
			_warned[sound_id] = true
			push_warning("Audio: unknown sound '%s'" % sound_id)
		return false
	var player := _free_voice()
	player.stream = stream
	player.pitch_scale = pitch_scale if pitch_scale > 0.0 else 1.0
	player.play()
	return true


## The stream `play_sfx(id)` plays: the override file if there is one, else the
## synthesized sound; null when neither exists. Cached.
func sfx_stream(sound_id: String) -> AudioStream:
	if _streams.has(sound_id):
		return _streams[sound_id]
	var stream := _load_override(sfx_root, sound_id, SFX_EXTENSIONS)
	if stream == null:
		var data: Variant = _content()
		if data != null:
			var params: Dictionary = data.sound(sound_id)
			if not params.is_empty():
				stream = _SfxSynth.render(params, data.sfx_sample_rate())
	if stream != null:
		_streams[sound_id] = stream
	return stream


## True when `play_sfx(id)` would find an override file or sfx.json parameters.
func has_sfx(sound_id: String) -> bool:
	if _streams.has(sound_id) or not _override_path(sfx_root, sound_id, SFX_EXTENSIONS).is_empty():
		return true
	var data: Variant = _content()
	return data != null and not data.sound(sound_id).is_empty()


## True when the sound comes from a file in `sfx_root`.
func is_sfx_overridden(sound_id: String) -> bool:
	return not _override_path(sfx_root, sound_id, SFX_EXTENSIONS).is_empty()


## Builds (and caches) the stream of every sound in sfx.json.
func preload_sfx() -> void:
	var data: Variant = _content()
	if data == null:
		return
	for sound_id in data.sound_ids():
		sfx_stream(sound_id)


## Drops the cached streams and the "warned once" ids, so the next play reads the
## current content and override files.
func clear_cache() -> void:
	_streams.clear()
	_warned.clear()


func _free_voice() -> AudioStreamPlayer:
	for i in SFX_VOICES:
		var player := _sfx_players[(_next_voice + i) % SFX_VOICES]
		if not player.playing:
			_next_voice = (_next_voice + i + 1) % SFX_VOICES
			return player
	var oldest := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	return oldest


# --- music -----------------------------------------------------------------------

## Crossfades over `fade` seconds to the track `<music_root>/<id>.ogg|wav`. Playing
## the current track again does nothing. An unknown id warns and changes nothing.
func play_music(music_id: String, fade: float = DEFAULT_FADE) -> void:
	if music_id == _music_id and _music_players[_music_active].playing:
		return
	var stream := _load_override(music_root, music_id, MUSIC_EXTENSIONS)
	if stream == null:
		push_warning("Audio: no music '%s' in %s (.ogg or .wav)" % [music_id, music_root])
		return
	_music_active = 1 - _music_active
	var player := _music_players[_music_active]
	_music_id = music_id
	player.stream = stream
	player.play()
	_crossfade(player, fade)


## Fades the music out over `fade` seconds and stops it.
func stop_music(fade: float = DEFAULT_FADE) -> void:
	_music_id = ""
	_crossfade(null, fade)


## The id of the track playing (or fading in); empty when none.
func current_music() -> String:
	return _music_id


## True when a track file exists for `music_id`.
func has_music(music_id: String) -> bool:
	return not _override_path(music_root, music_id, MUSIC_EXTENSIONS).is_empty()


## Fades `fade_in` (null for none) from silence to full volume, and every other playing
## music player from its current volume to silence, then stops those. Without a fade
## time, or outside the tree, the change is immediate.
func _crossfade(fade_in: AudioStreamPlayer, fade: float) -> void:
	if _music_tween != null:
		_music_tween.kill()
		_music_tween = null
	var fading_out: Array[AudioStreamPlayer] = []
	for player in _music_players:
		if player != fade_in and player.playing:
			fading_out.append(player)
	if fade <= 0.0 or not is_inside_tree():
		if fade_in != null:
			fade_in.volume_linear = 1.0
		_stop_players(fading_out)
		return
	if fade_in == null and fading_out.is_empty():
		return
	_music_tween = create_tween().set_parallel()
	if fade_in != null:
		fade_in.volume_linear = 0.0
		_music_tween.tween_property(fade_in, ^"volume_linear", 1.0, fade)
	for player in fading_out:
		# A player caught mid-fade finishes in proportion to the volume it has left.
		_music_tween.tween_property(player, ^"volume_linear", 0.0, fade * player.volume_linear)
	_music_tween.chain().tween_callback(_stop_players.bind(fading_out))


func _stop_players(players: Array[AudioStreamPlayer]) -> void:
	for player in players:
		player.stop()
		player.volume_linear = 1.0


func _on_music_finished(player: AudioStreamPlayer) -> void:
	# Loop the current track, even if it wasn't imported with looping.
	if player == _music_players[_music_active] and not _music_id.is_empty():
		player.play()


# --- helpers ---------------------------------------------------------------------

## The first `<root>/<id>.<ext>` resource that exists; empty when none.
func _override_path(root: String, item_id: String, extensions: PackedStringArray) -> String:
	if item_id.is_empty():
		return ""
	for extension in extensions:
		var path := root.path_join("%s.%s" % [item_id, extension])
		if ResourceLoader.exists(path):
			return path
	return ""


func _load_override(root: String, item_id: String, extensions: PackedStringArray) -> AudioStream:
	var path := _override_path(root, item_id, extensions)
	if path.is_empty():
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("Audio: %s is not an audio stream" % path)
	return stream


func _content() -> Node:
	if content != null:
		return content
	return get_node_or_null(^"/root/Content")
