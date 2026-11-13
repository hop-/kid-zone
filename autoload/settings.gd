extends Node
## The player's settings, saved in a `ConfigFile` (`user://settings.cfg` by default):
## `sfx_on`, `music_on`, `sfx_volume_db`, `music_volume_db`, `locale` and
## `letter_case`.
##
## - Setting a property applies it, saves the file and emits `changed`, so a sound
##   toggle is just `Settings.sfx_on = not Settings.sfx_on`.
## - The mute flags and volumes drive the `SFX` and `Music` buses
##   (`default_bus_layout.tres`). They are applied on load and on every change.
## - `locale` picks the word pack (`Content` reads it on load) and falls back to `en`.
## - `letter_case` (`upper` or `lower`) is how the word game shows its words and
##   letters; `display_text()` applies it. The content itself stays lowercase.
##
## Registered as the `Settings` autoload, first, so `Content` sees the locale. It loads
## `DEFAULT_PATH` on startup and only writes it when a setting changes. Tests must not
## touch that file: call `load_from(<temp path>)` on the autoload or on an instance
## (`preload("res://autoload/settings.gd").new()`, free it afterwards), then restore
## the autoload with `load_from(Settings.DEFAULT_PATH)`, which only reads. An instance
## that never loaded has an empty `path` and saves nothing.

## Emitted after a setting changes and after `load_from()`.
signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const DEFAULT_LOCALE := "en"
const LETTER_CASE_UPPER := "upper"
const LETTER_CASE_LOWER := "lower"
## Volumes are clamped to this range, in dB.
const MIN_VOLUME_DB := -80.0
const MAX_VOLUME_DB := 6.0
const DEFAULTS := {
	"sfx_on": true,
	"music_on": true,
	"sfx_volume_db": 0.0,
	"music_volume_db": 0.0,
	"locale": DEFAULT_LOCALE,
	"letter_case": LETTER_CASE_UPPER,
}

## The file this instance loads and saves; empty means "don't save".
var path: String = ""

var sfx_on: bool:
	get:
		return _values["sfx_on"]
	set(value):
		_update("sfx_on", value)
var music_on: bool:
	get:
		return _values["music_on"]
	set(value):
		_update("music_on", value)
var sfx_volume_db: float:
	get:
		return _values["sfx_volume_db"]
	set(value):
		_update("sfx_volume_db", clampf(value, MIN_VOLUME_DB, MAX_VOLUME_DB))
var music_volume_db: float:
	get:
		return _values["music_volume_db"]
	set(value):
		_update("music_volume_db", clampf(value, MIN_VOLUME_DB, MAX_VOLUME_DB))
## A locale code such as `en` or `en_US`; empty is stored as `en`.
var locale: String:
	get:
		return _values["locale"]
	set(value):
		_update("locale", value if not value.is_empty() else DEFAULT_LOCALE)
## `LETTER_CASE_UPPER` or `LETTER_CASE_LOWER`; anything else is stored as upper.
var letter_case: String:
	get:
		return _values["letter_case"]
	set(value):
		_update("letter_case", _sanitized("letter_case", value))

## The current values, keyed like `DEFAULTS`; the properties above read and write it.
var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_from(DEFAULT_PATH)


## Resets every setting to its default, reads `file_path` (a missing file keeps the
## defaults), makes it the save path, applies the buses and emits `changed`. Values of
## the wrong type are ignored. Returns the `ConfigFile.load` error; `OK` or
## `ERR_FILE_NOT_FOUND` are normal.
func load_from(file_path: String) -> Error:
	path = file_path
	_values = DEFAULTS.duplicate()
	var config := ConfigFile.new()
	var error := config.load(file_path)
	if error == OK:
		for key: String in DEFAULTS:
			var value: Variant = config.get_value(SECTION, key, DEFAULTS[key])
			_values[key] = _sanitized(key, value)
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Settings: can't read %s (%s); using the defaults"
				% [file_path, error_string(error)])
	apply()
	changed.emit()
	return error


## Writes every setting to `path`. Does nothing (and returns `OK`) when `path` is empty.
func save() -> Error:
	if path.is_empty():
		return OK
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value(SECTION, key, _values[key])
	var error := config.save(path)
	if error != OK:
		push_warning("Settings: can't save %s (%s)" % [path, error_string(error)])
	return error


## Sets mute and volume on the `SFX` and `Music` buses from the current settings.
func apply() -> void:
	_apply_bus(SFX_BUS, _values["sfx_on"], _values["sfx_volume_db"])
	_apply_bus(MUSIC_BUS, _values["music_on"], _values["music_volume_db"])


## The settings as a dictionary (a copy), keyed like `DEFAULTS`.
func values() -> Dictionary:
	return _values.duplicate()


## `text` as the word game shows it: in uppercase when `letter_case` is upper, else
## unchanged (content is lowercase).
func display_text(text: String) -> String:
	return text.to_upper() if _values["letter_case"] == LETTER_CASE_UPPER else text


func _update(key: String, value: Variant) -> void:
	if _values[key] == value:
		return
	_values[key] = value
	apply()
	save()
	changed.emit()


func _apply_bus(bus_name: StringName, on: bool, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("Settings: no audio bus '%s'" % bus_name)
		return
	AudioServer.set_bus_mute(index, not on)
	AudioServer.set_bus_volume_db(index, volume_db)


## `value` if it has the right type for `key`, else the default. Volumes are clamped,
## and `letter_case` must be upper or lower.
static func _sanitized(key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	if key == "letter_case":
		return value if value is String and value in [LETTER_CASE_UPPER, LETTER_CASE_LOWER] \
				else fallback
	match typeof(fallback):
		TYPE_BOOL:
			return value if value is bool else fallback
		TYPE_FLOAT:
			if value is float or value is int:
				return clampf(float(value), MIN_VOLUME_DB, MAX_VOLUME_DB)
			return fallback
		TYPE_STRING:
			return value if value is String and not String(value).is_empty() else fallback
	return fallback
