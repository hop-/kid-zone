extends Node
## Loads, resolves and validates the game content: `catalog.json`, `palette.json`,
## `objects.json`, `sfx.json`, `font.json`, the sprite grids in `sprites/*.json` and
## the `<locale>/words.json` word pack under a content root (`res://content` by
## default).
##
## Registered as the `Content` autoload, which loads the default root on startup and
## reports every `validate()` problem with `push_error` without failing startup. Tests
## can make their own instance (`preload("res://autoload/content.gd").new()`) and
## call `load_content(<fixture root>)`, or reload the autoload from a fixture root and
## restore it afterwards with `load_content()`.
##
## Loading never crashes on bad data: unreadable files and invalid JSON are recorded,
## the accessors return empty values, and `validate()` lists every problem as
## `"<file>: <problem>"`. The accessors return the loaded data itself: treat it as
## read-only.

const DEFAULT_ROOT := "res://content"
## The word pack used when the requested locale has none.
const FALLBACK_LOCALE := "en"

const CATALOG_FILE := "catalog.json"
const PALETTE_FILE := "palette.json"
const OBJECTS_FILE := "objects.json"
const SFX_FILE := "sfx.json"
const WORDS_FILE := "words.json"
const UI_FILE := "locale/ui.csv"
const FONT_FILE := "font.json"
## The sprite grid files, read in this order when they exist. Sprite ids are unique
## across all of them. A listed file may be absent (ui.json is only for future UI
## pieces); `validate()` reports every referenced sprite that has no grid or PNG.
const SPRITE_FILES: PackedStringArray = [
	"sprites/icons.json", "sprites/objects.json", "sprites/words.json", "sprites/ui.json",
]
## A PNG here with a sprite's id overrides its grid (see the `Art` autoload).
const SPRITE_OVERRIDE_ROOT := "res://assets/sprites"

## Sound effects the code plays. `validate()` reports any missing from sfx.json.
const REQUIRED_SFX: PackedStringArray = ["tap", "back", "correct", "wrong", "fanfare"]
## UI keys the screens use directly. Catalog title keys are checked as well.
const REQUIRED_UI_KEYS: PackedStringArray = ["APP_TITLE", "ROUND_AGAIN", "ROUND_HOME"]
## Sprites the UI draws directly. Catalog icons, object sprites and word pictures
## are checked as well.
const REQUIRED_SPRITES: PackedStringArray = [
	"icon_sound_on", "icon_sound_off", "icon_case_upper", "icon_case_lower", "icon_back",
	"icon_star_empty", "icon_star_gold", "icon_star_silver", "icon_again", "icon_home",
	"app_icon",
]
## Characters the games draw besides words and UI strings: the math games' digits and
## signs.
const REQUIRED_GLYPHS := "0123456789+-=?"
## Glyph pixels: ink and empty.
const GLYPH_PIXELS := "#."
## The widest inked glyph, in pixels.
const MAX_GLYPH_WIDTH := 5
const WAVES: PackedStringArray = ["square", "triangle", "noise"]
## Every blank must have this many valid distractors: the missing-letter game shows
## the answer plus 3 wrong letters (see `MissingLetterGenerator`).
const MIN_DISTRACTORS := 3
const DEFAULT_ROUND_LENGTH := 10
const MAX_LEVEL_STARS := 3

const _ID_FIRST_CHARS := "abcdefghijklmnopqrstuvwxyz"
const _ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

var _root: String = DEFAULT_ROOT
var _catalog: Dictionary = {}
var _palette: Dictionary = {}
var _objects: Dictionary = {}
var _sfx: Dictionary = {}
var _words: Dictionary = {}
var _font: Dictionary = {}
## Sprite id -> its grid ({"size": [w, h], "rows": [...]}) from any sprite file.
var _sprites: Dictionary[String, Dictionary] = {}
## Sprite id -> the sprite file it came from, for messages.
var _sprite_files: Dictionary[String, String] = {}
## Problems found while merging the sprite files (bad entries, duplicate ids).
var _sprite_problems: PackedStringArray = []
## The word pack's path relative to the root, such as "en/words.json"; "" if none.
var _words_file: String = ""
var _words_locale: String = ""
var _load_errors: PackedStringArray = []


func _ready() -> void:
	load_content()
	for problem in validate():
		push_error("Content: %s" % problem)


# --- loading ---------------------------------------------------------------------

## Loads every content file from `root`. The word pack is resolved for `locale`, or
## for `Settings.locale` when `locale` is empty, with a fallback to `en`.
func load_content(root: String = DEFAULT_ROOT, locale: String = "") -> void:
	_root = root.trim_suffix("/")
	_load_errors.clear()
	_catalog = _read_json(CATALOG_FILE)
	_palette = _read_json(PALETTE_FILE)
	_objects = _read_json(OBJECTS_FILE)
	_sfx = _read_json(SFX_FILE)
	_font = _read_json(FONT_FILE)
	_load_sprites()
	if locale.is_empty():
		locale = _settings_locale()
	_words_locale = resolve_words_locale(_root, locale)
	_words_file = "" if _words_locale.is_empty() else _words_locale.path_join(WORDS_FILE)
	if _words_file.is_empty():
		_words = {}
		_load_errors.append("%s: no word pack for locale '%s' (or the fallback '%s') under %s"
				% [WORDS_FILE, locale, FALLBACK_LOCALE, _root])
	else:
		_words = _read_json(_words_file)


## Reads every existing file of `SPRITE_FILES` into `_sprites`.
func _load_sprites() -> void:
	_sprites.clear()
	_sprite_files.clear()
	_sprite_problems.clear()
	for file in SPRITE_FILES:
		if not FileAccess.file_exists(_root.path_join(file)):
			continue
		var data := _read_json(file)
		if data.is_empty():
			continue
		var sprites: Variant = data.get("sprites")
		if not sprites is Dictionary:
			_sprite_problems.append("%s: 'sprites' must be an object" % file)
			continue
		for id: Variant in sprites:
			var label := "sprite '%s'" % id
			if not _is_id(id):
				_sprite_problems.append("%s: %s: the id must be lowercase snake_case" % [file, label])
				continue
			if _sprites.has(id):
				_sprite_problems.append("%s: %s: duplicate id (also in %s)"
						% [file, label, _sprite_files[id]])
				continue
			if not sprites[id] is Dictionary:
				_sprite_problems.append("%s: %s: must be an object" % [file, label])
				continue
			_sprites[id] = sprites[id]
			_sprite_files[id] = file


## The locale folder under `root` whose words.json serves `locale`: the exact locale
## ("en_US"), then its language ("en"), then `FALLBACK_LOCALE`. "" if none exists.
static func resolve_words_locale(root: String, locale: String) -> String:
	var candidates: PackedStringArray = []
	if not locale.is_empty():
		candidates.append(locale)
		candidates.append(locale.replace("-", "_").get_slice("_", 0))
	candidates.append(FALLBACK_LOCALE)
	for candidate in candidates:
		if FileAccess.file_exists(root.path_join(candidate).path_join(WORDS_FILE)):
			return candidate
	return ""


func _read_json(relative_path: String) -> Dictionary:
	var path := _root.path_join(relative_path)
	if not FileAccess.file_exists(path):
		_load_errors.append("%s: file not found (%s)" % [relative_path, path])
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		_load_errors.append("%s: cannot read (%s)" % [relative_path,
				error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		_load_errors.append("%s: invalid JSON at line %d: %s"
				% [relative_path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		_load_errors.append("%s: the top level must be a JSON object" % relative_path)
		return {}
	return json.data


## `Settings.locale` if the Settings autoload exists and has one, else `en`.
func _settings_locale() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return FALLBACK_LOCALE
	var settings := tree.root.get_node_or_null(^"Settings")
	if settings == null:
		return FALLBACK_LOCALE
	var value: Variant = settings.get("locale")
	if value is String and not String(value).is_empty():
		return value
	return FALLBACK_LOCALE


# --- catalog ---------------------------------------------------------------------

## The modes in menu order.
func modes() -> Array[Dictionary]:
	return _dicts(_catalog.get("modes"))


func mode(mode_id: String) -> Dictionary:
	for entry in _dicts(_catalog.get("modes")):
		if _is_text(entry.get("id"), mode_id):
			return entry
	return {}


## The games of a mode in menu order; empty for an unknown mode.
func games_for(mode_id: String) -> Array[Dictionary]:
	return _dicts(mode(mode_id).get("games"))


## The game entry with this id from any mode; {} if unknown.
func game(game_id: String) -> Dictionary:
	for mode_entry in _dicts(_catalog.get("modes")):
		for entry in _dicts(mode_entry.get("games")):
			if _is_text(entry.get("id"), game_id):
				return entry
	return {}


## The id of the mode that holds this game; "" if unknown.
func mode_of(game_id: String) -> String:
	for mode_entry in _dicts(_catalog.get("modes")):
		for entry in _dicts(mode_entry.get("games")):
			if _is_text(entry.get("id"), game_id):
				return str(mode_entry.get("id", ""))
	return ""


## The game's levels in menu order; empty when it has none (level select is skipped).
func levels_for(game_id: String) -> Array[Dictionary]:
	return _dicts(game(game_id).get("levels"))


func level(game_id: String, level_id: String) -> Dictionary:
	for entry in levels_for(game_id):
		if _is_text(entry.get("id"), level_id):
			return entry
	return {}


func round_length(game_id: String) -> int:
	var value: Variant = game(game_id).get("round_length", DEFAULT_ROUND_LENGTH)
	return int(value) if _is_int_like(value) and int(value) >= 1 else DEFAULT_ROUND_LENGTH


## The game's `params` overlaid with the level's `params` (the level wins). An empty
## or unknown `level_id` gives the game's params alone.
func merged_params(game_id: String, level_id: String = "") -> Dictionary:
	var merged: Dictionary = {}
	var game_params: Variant = game(game_id).get("params", {})
	if game_params is Dictionary:
		merged = (game_params as Dictionary).duplicate(true)
	if not level_id.is_empty():
		var level_params: Variant = level(game_id, level_id).get("params", {})
		if level_params is Dictionary:
			merged.merge((level_params as Dictionary).duplicate(true), true)
	return merged


# --- palette, objects, words, sfx -----------------------------------------------

## The raw palette.json data.
func palette() -> Dictionary:
	return _palette


## The grid character that means a transparent pixel, such as ".".
func transparent_key() -> String:
	var value: Variant = _palette.get("transparent", ".")
	return value if value is String else "."


## Grid character -> Color for every valid palette entry.
func palette_by_key() -> Dictionary[String, Color]:
	var result: Dictionary[String, Color] = {}
	var colors: Variant = _palette.get("colors")
	if colors is Dictionary:
		for key: Variant in colors:
			var entry: Variant = colors[key]
			if entry is Dictionary and _is_color(entry.get("rgb")):
				result[String(key)] = Color.html(String(entry["rgb"]))
	return result


## The palette color with this name, or magenta (and an error) if there is none.
func color(color_name: String) -> Color:
	var colors: Variant = _palette.get("colors")
	if colors is Dictionary:
		for entry: Variant in colors.values():
			if entry is Dictionary and _is_text(entry.get("name"), color_name) and _is_color(entry.get("rgb")):
				return Color.html(String(entry["rgb"]))
	push_error("Content: unknown palette color '%s'" % color_name)
	return Color.MAGENTA


func objects() -> Array[Dictionary]:
	return _dicts(_objects.get("objects"))


func object_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for entry in objects():
		if _is_id(entry.get("id")):
			ids.append(entry["id"])
	return ids


## The word pack for the resolved locale, as `MissingLetterGenerator` takes it.
func word_pack() -> Dictionary:
	return _words


func sfx_sample_rate() -> int:
	var value: Variant = _sfx.get("sample_rate", 22050)
	return int(value) if _is_int_like(value) and int(value) > 0 else 22050


func sound_ids() -> PackedStringArray:
	var sounds: Variant = _sfx.get("sounds")
	return PackedStringArray((sounds as Dictionary).keys()) if sounds is Dictionary else PackedStringArray()


## The synth parameters of a sound effect; {} if unknown.
func sound(sound_id: String) -> Dictionary:
	var sounds: Variant = _sfx.get("sounds")
	if sounds is Dictionary and sounds.get(sound_id) is Dictionary:
		return sounds[sound_id]
	return {}


# --- sprites and font -----------------------------------------------------------

## Every sprite id that has a grid, in file order.
func sprite_ids() -> PackedStringArray:
	return PackedStringArray(_sprites.keys())


func has_sprite_grid(sprite_id: String) -> bool:
	return _sprites.has(sprite_id)


## A sprite's grid, `{"size": [w, h], "rows": [...]}`; {} if it has none.
func sprite_grid(sprite_id: String) -> Dictionary:
	return _sprites.get(sprite_id, {})


## The path a PNG overriding this sprite would have.
static func sprite_override_path(sprite_id: String, root: String = SPRITE_OVERRIDE_ROOT) -> String:
	return root.path_join(sprite_id + ".png")


## True when the sprite has a grid or an override PNG.
func sprite_exists(sprite_id: String) -> bool:
	return _sprites.has(sprite_id) or ResourceLoader.exists(sprite_override_path(sprite_id))


## The raw font.json data, as `FontBuilder.build()` takes it.
func font_data() -> Dictionary:
	return _font


func has_glyph(character: String) -> bool:
	var glyphs: Variant = _font.get("glyphs")
	return glyphs is Dictionary and (glyphs as Dictionary).has(character)


## Every character the game draws: the word pack's words and alphabet in both their
## stored case and uppercase (the word game's letter case, see
## `Settings.display_text()`), `REQUIRED_GLYPHS` and the fallback-locale UI strings.
func required_glyph_chars() -> String:
	var chars: Dictionary[String, bool] = {}
	var texts: PackedStringArray = [REQUIRED_GLYPHS]
	if _words.get("alphabet") is String:
		texts.append(_words["alphabet"])
		texts.append(String(_words["alphabet"]).to_upper())
	for entry in _dicts(_words.get("words")):
		if entry.get("text") is String:
			texts.append(entry["text"])
			texts.append(String(entry["text"]).to_upper())
	texts.append_array(_ui_strings())
	for text in texts:
		for character in text:
			chars[character] = true
	return "".join(PackedStringArray(chars.keys()))


## The fallback-locale texts of every UI key the game uses.
func _ui_strings() -> PackedStringArray:
	var strings: PackedStringArray = []
	var translation := TranslationServer.get_translation_object(FALLBACK_LOCALE)
	if translation == null:
		return strings
	for key in _ui_keys():
		var text := String(translation.get_message(key))
		if not text.is_empty():
			strings.append(text)
	return strings


# --- validation ------------------------------------------------------------------

## Every structural problem in the loaded content, as "<file>: <problem>". Empty
## means valid.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = _load_errors.duplicate()
	problems.append_array(_validate_palette())
	problems.append_array(_validate_catalog())
	problems.append_array(_validate_scenes())
	problems.append_array(_validate_ui_keys())
	problems.append_array(_validate_objects())
	problems.append_array(_validate_words())
	problems.append_array(_validate_sfx())
	problems.append_array(_sprite_problems)
	problems.append_array(_validate_sprites())
	problems.append_array(_validate_sprite_refs())
	problems.append_array(_validate_font())
	problems.append_array(_validate_glyph_coverage())
	return problems


func _validate_palette() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _palette.is_empty():
		return problems
	var f := PALETTE_FILE
	var transparent: Variant = _palette.get("transparent")
	if not (transparent is String and String(transparent).length() == 1):
		problems.append("%s: 'transparent' must be a single character" % f)
	var colors: Variant = _palette.get("colors")
	if not (colors is Dictionary and not (colors as Dictionary).is_empty()):
		problems.append("%s: 'colors' must be a non-empty object" % f)
		return problems
	var names: Dictionary[String, bool] = {}
	for key: Variant in colors:
		var entry: Variant = colors[key]
		var label := "color '%s'" % key
		if String(key).length() != 1:
			problems.append("%s: %s: the key must be a single character" % [f, label])
		elif _is_text(transparent, String(key)):
			problems.append("%s: %s: the key is the transparent character" % [f, label])
		if not entry is Dictionary:
			problems.append("%s: %s: must be an object" % [f, label])
			continue
		var color_name: Variant = entry.get("name")
		if not _is_id(color_name):
			problems.append("%s: %s: missing or invalid name" % [f, label])
		elif names.has(color_name):
			problems.append("%s: %s: duplicate name '%s'" % [f, label, color_name])
		else:
			names[color_name] = true
		if not _is_color(entry.get("rgb")):
			problems.append("%s: %s: invalid rgb %s" % [f, label, entry.get("rgb")])
	return problems


func _validate_catalog() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _catalog.is_empty():
		return problems
	var f := CATALOG_FILE
	var version: Variant = _catalog.get("version")
	if not (_is_int_like(version) and int(version) >= 1):
		problems.append("%s: 'version' must be an integer >= 1" % f)
	var mode_list: Variant = _catalog.get("modes")
	if not (mode_list is Array and not (mode_list as Array).is_empty()):
		problems.append("%s: 'modes' must be a non-empty array" % f)
		return problems
	var palette_names := _palette_names()
	var mode_ids: Dictionary[String, bool] = {}
	var game_ids: Dictionary[String, bool] = {}
	for i in (mode_list as Array).size():
		var entry: Variant = mode_list[i]
		if not entry is Dictionary:
			problems.append("%s: mode #%d: must be an object" % [f, i + 1])
			continue
		var label := _label("mode", entry, i)
		problems.append_array(_check_id(f, label, entry.get("id"), mode_ids))
		problems.append_array(_check_strings(f, label, entry, ["title_key", "icon"]))
		var color_name: Variant = entry.get("color")
		if not color_name is String:
			problems.append("%s: %s: missing 'color'" % [f, label])
		elif not _palette.is_empty() and not palette_names.has(color_name):
			problems.append("%s: %s: unknown palette color '%s'" % [f, label, color_name])
		var games: Variant = entry.get("games")
		if not (games is Array and not (games as Array).is_empty()):
			problems.append("%s: %s: 'games' must be a non-empty array" % [f, label])
			continue
		for j in (games as Array).size():
			problems.append_array(_validate_game(games[j], j, label, game_ids))
	return problems


func _validate_game(entry: Variant, index: int, mode_label: String,
		game_ids: Dictionary[String, bool]) -> PackedStringArray:
	var problems: PackedStringArray = []
	var f := CATALOG_FILE
	if not entry is Dictionary:
		problems.append("%s: %s: game #%d: must be an object" % [f, mode_label, index + 1])
		return problems
	var label := _label("game", entry, index)
	problems.append_array(_check_id(f, label, entry.get("id"), game_ids))
	problems.append_array(_check_strings(f, label, entry, ["title_key", "icon", "scene"]))
	if entry.has("round_length"):
		var length: Variant = entry["round_length"]
		if not (_is_int_like(length) and int(length) >= 1):
			problems.append("%s: %s: 'round_length' must be an integer >= 1" % [f, label])
	if entry.has("params") and not entry["params"] is Dictionary:
		problems.append("%s: %s: 'params' must be an object" % [f, label])
	if not entry.has("levels"):
		return problems
	var levels: Variant = entry["levels"]
	if not (levels is Array and not (levels as Array).is_empty()):
		problems.append("%s: %s: 'levels' must be a non-empty array when present" % [f, label])
		return problems
	var level_ids: Dictionary[String, bool] = {}
	for k in (levels as Array).size():
		var level_entry: Variant = levels[k]
		if not level_entry is Dictionary:
			problems.append("%s: %s: level #%d: must be an object" % [f, label, k + 1])
			continue
		var level_label := "%s %s" % [label, _label("level", level_entry, k)]
		problems.append_array(_check_id(f, level_label, level_entry.get("id"), level_ids))
		problems.append_array(_check_strings(f, level_label, level_entry, ["title_key"]))
		var stars: Variant = level_entry.get("stars")
		if not (_is_int_like(stars) and int(stars) >= 1 and int(stars) <= MAX_LEVEL_STARS):
			problems.append("%s: %s: 'stars' must be an integer 1-%d"
					% [f, level_label, MAX_LEVEL_STARS])
		if level_entry.has("params") and not level_entry["params"] is Dictionary:
			problems.append("%s: %s: 'params' must be an object" % [f, level_label])
	return problems


## Catalog scenes that don't exist. Until the game scenes are added these are the
## expected startup notices.
func _validate_scenes() -> PackedStringArray:
	var problems: PackedStringArray = []
	for mode_entry in modes():
		for entry in _dicts(mode_entry.get("games")):
			var scene: Variant = entry.get("scene")
			if scene is String and not String(scene).is_empty() and not ResourceLoader.exists(scene):
				problems.append("%s: game '%s': scene not found: %s"
						% [CATALOG_FILE, entry.get("id", "?"), scene])
	return problems


## Catalog title keys and the code's UI keys must have a registered translation
## for the fallback locale (from locale/ui.csv).
func _validate_ui_keys() -> PackedStringArray:
	var problems: PackedStringArray = []
	var translation := TranslationServer.get_translation_object(FALLBACK_LOCALE)
	if translation == null:
		problems.append("%s: no '%s' translation is registered (project setting "
				% [UI_FILE, FALLBACK_LOCALE] + "internationalization/locale/translations)")
		return problems
	var keys := _ui_keys()
	for key in keys:
		if String(translation.get_message(key)).is_empty():
			problems.append("%s: no '%s' text for key '%s' (%s)"
					% [UI_FILE, FALLBACK_LOCALE, key, keys[key]])
	return problems


## Every UI key the game uses -> where it is used: `REQUIRED_UI_KEYS` and the
## catalog title keys.
func _ui_keys() -> Dictionary[String, String]:
	var keys: Dictionary[String, String] = {}
	for key in REQUIRED_UI_KEYS:
		keys[key] = "used by the UI"
	for mode_entry in modes():
		_add_key(keys, mode_entry, "%s mode '%s'" % [CATALOG_FILE, mode_entry.get("id", "?")])
		for game_entry in _dicts(mode_entry.get("games")):
			_add_key(keys, game_entry, "%s game '%s'" % [CATALOG_FILE, game_entry.get("id", "?")])
			for level_entry in _dicts(game_entry.get("levels")):
				_add_key(keys, level_entry, "%s game '%s' level '%s'"
						% [CATALOG_FILE, game_entry.get("id", "?"), level_entry.get("id", "?")])
	return keys


static func _add_key(keys: Dictionary[String, String], entry: Dictionary, where: String) -> void:
	var key: Variant = entry.get("title_key")
	if key is String and not String(key).is_empty():
		keys[key] = where


func _validate_objects() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _objects.is_empty():
		return problems
	var f := OBJECTS_FILE
	var list: Variant = _objects.get("objects")
	if not (list is Array and not (list as Array).is_empty()):
		problems.append("%s: 'objects' must be a non-empty array" % f)
		return problems
	var ids: Dictionary[String, bool] = {}
	for i in (list as Array).size():
		var entry: Variant = list[i]
		if not entry is Dictionary:
			problems.append("%s: object #%d: must be an object" % [f, i + 1])
			continue
		var label := _label("object", entry, i)
		problems.append_array(_check_id(f, label, entry.get("id"), ids))
		problems.append_array(_check_strings(f, label, entry, ["category", "sprite"]))
	return problems


func _validate_words() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _words.is_empty():
		return problems
	var f := _words_file
	if not _is_text(_words.get("locale"), _words_locale):
		problems.append("%s: 'locale' must be '%s'" % [f, _words_locale])
	var alphabet_value: Variant = _words.get("alphabet")
	var alphabet: PackedStringArray = []
	if not (alphabet_value is String and not String(alphabet_value).is_empty()):
		problems.append("%s: 'alphabet' must be a non-empty string" % f)
	else:
		for letter in String(alphabet_value):
			if alphabet.has(letter):
				problems.append("%s: 'alphabet' repeats '%s'" % [f, letter])
			else:
				alphabet.append(letter)
	var real_words: Dictionary[String, bool] = {}
	var valid_words: Array[Dictionary] = []
	var list: Variant = _words.get("words")
	if not (list is Array and not (list as Array).is_empty()):
		problems.append("%s: 'words' must be a non-empty array" % f)
	else:
		var ids: Dictionary[String, bool] = {}
		for i in (list as Array).size():
			var entry: Variant = list[i]
			if not entry is Dictionary:
				problems.append("%s: word #%d: must be an object" % [f, i + 1])
				continue
			var label := _label("word", entry, i)
			problems.append_array(_check_id(f, label, entry.get("id"), ids))
			problems.append_array(_check_strings(f, label, entry, ["text", "picture"]))
			var text: Variant = entry.get("text")
			if not (text is String and not String(text).is_empty()):
				continue
			real_words[String(text).to_lower()] = true
			var word_ok := true
			var outside := _chars_outside(text, alphabet)
			if not alphabet.is_empty() and not outside.is_empty():
				problems.append("%s: %s: '%s' has characters outside the alphabet: %s"
						% [f, label, text, " ".join(outside)])
				word_ok = false
			if entry.has("blank"):
				var blank_problem := _check_blank(entry["blank"], String(text).length())
				if not blank_problem.is_empty():
					problems.append("%s: %s: %s" % [f, label, blank_problem])
					word_ok = false
			if word_ok:
				valid_words.append(entry)
	var known: Variant = _words.get("known_words")
	if not known is Array:
		problems.append("%s: 'known_words' must be an array" % f)
	else:
		var seen: Dictionary[String, bool] = {}
		for value: Variant in known:
			if not (value is String and not String(value).is_empty()):
				problems.append("%s: known_words: invalid entry %s" % [f, value])
				continue
			var outside := _chars_outside(value, alphabet)
			if not alphabet.is_empty() and not outside.is_empty():
				problems.append("%s: known_words: '%s' has characters outside the alphabet: %s"
						% [f, value, " ".join(outside)])
			if seen.has(value):
				problems.append("%s: known_words: duplicate '%s'" % [f, value])
			seen[value] = true
			real_words[String(value).to_lower()] = true
	if alphabet.is_empty():
		return problems
	for entry in valid_words:
		var text := String(entry["text"])
		for blank_index in _blank_indices(entry, text.length()):
			var count := count_distractors(text, blank_index, alphabet, real_words)
			if count < MIN_DISTRACTORS:
				problems.append("%s: word '%s': blank %d has only %d valid distractors, needs %d"
						% [f, entry.get("id", text), blank_index, count, MIN_DISTRACTORS])
	return problems


## How many alphabet letters other than the answer can fill the blank without
## spelling a word in `real_words` (lowercase pack words and known words): the
## missing-letter game's distractor rule, `QuestionUtils.letter_distractors()`.
static func count_distractors(text: String, blank_index: int, alphabet: PackedStringArray,
		real_words: Dictionary) -> int:
	return QuestionUtils.letter_distractors(text, blank_index, alphabet, real_words).size()


func _validate_sfx() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _sfx.is_empty():
		return problems
	var f := SFX_FILE
	var rate: Variant = _sfx.get("sample_rate")
	if not (_is_int_like(rate) and int(rate) > 0):
		problems.append("%s: 'sample_rate' must be a positive integer" % f)
	var sounds: Variant = _sfx.get("sounds")
	if not (sounds is Dictionary and not (sounds as Dictionary).is_empty()):
		problems.append("%s: 'sounds' must be a non-empty object" % f)
		return problems
	for sound_id: Variant in sounds:
		var label := "sound '%s'" % sound_id
		if not _is_id(sound_id):
			problems.append("%s: %s: the id must be lowercase snake_case" % [f, label])
		var entry: Variant = sounds[sound_id]
		if not entry is Dictionary:
			problems.append("%s: %s: must be an object" % [f, label])
			continue
		var wave: Variant = entry.get("wave")
		if not (wave is String and WAVES.has(wave)):
			problems.append("%s: %s: 'wave' must be one of %s" % [f, label, ", ".join(WAVES)])
		var has_notes: bool = entry.has("notes")
		var has_sweep: bool = entry.has("sweep")
		if has_notes == has_sweep:
			problems.append("%s: %s: needs either 'notes' or 'sweep' (exactly one)" % [f, label])
		if has_notes and not _is_notes(entry["notes"]):
			problems.append("%s: %s: 'notes' must be a non-empty list of [hz, seconds] > 0"
					% [f, label])
		if has_sweep:
			var sweep: Variant = entry["sweep"]
			if not (sweep is Array and (sweep as Array).size() == 2
					and _is_positive(sweep[0]) and _is_positive(sweep[1])):
				problems.append("%s: %s: 'sweep' must be [from_hz, to_hz] > 0" % [f, label])
			if not _is_positive(entry.get("duration")):
				problems.append("%s: %s: a sweep needs 'duration' > 0" % [f, label])
		var volume: Variant = entry.get("volume", 1.0)
		if not (_is_number(volume) and float(volume) >= 0.0 and float(volume) <= 1.0):
			problems.append("%s: %s: 'volume' must be 0-1" % [f, label])
		for key in ["attack", "release"]:
			var value: Variant = entry.get(key, 0.0)
			if not (_is_number(value) and float(value) >= 0.0):
				problems.append("%s: %s: '%s' must be >= 0" % [f, label, key])
	for required in REQUIRED_SFX:
		if not (sounds as Dictionary).has(required):
			problems.append("%s: missing sound '%s' (used by the code)" % [f, required])
	return problems


## Each sprite grid: `size` is [w, h] of positive integers, there are h rows of w
## characters, and every character is a palette key or the transparent key.
func _validate_sprites() -> PackedStringArray:
	var problems: PackedStringArray = []
	var keys := palette_by_key()
	var transparent := transparent_key()
	for id in _sprites:
		var f := _sprite_files[id]
		var label := "sprite '%s'" % id
		var grid := _sprites[id]
		var size: Variant = grid.get("size")
		if not (size is Array and (size as Array).size() == 2 and _is_int_like(size[0])
				and _is_int_like(size[1]) and int(size[0]) >= 1 and int(size[1]) >= 1):
			problems.append("%s: %s: 'size' must be [width, height] of positive integers" % [f, label])
			continue
		var width := int(size[0])
		var height := int(size[1])
		var rows: Variant = grid.get("rows")
		if not rows is Array:
			problems.append("%s: %s: 'rows' must be an array of strings" % [f, label])
			continue
		if (rows as Array).size() != height:
			problems.append("%s: %s: has %d rows, 'size' says %d"
					% [f, label, (rows as Array).size(), height])
		var bad_chars: PackedStringArray = []
		for y in (rows as Array).size():
			var row: Variant = rows[y]
			if not row is String:
				problems.append("%s: %s: row %d is not a string" % [f, label, y])
				continue
			if String(row).length() != width:
				problems.append("%s: %s: row %d has %d pixels, 'size' says %d"
						% [f, label, y, String(row).length(), width])
			for character in String(row):
				if character != transparent and not keys.has(character) \
						and not bad_chars.has(character):
					bad_chars.append(character)
		if not bad_chars.is_empty():
			problems.append("%s: %s: characters that are not palette keys: %s"
					% [f, label, " ".join(bad_chars)])
	return problems


## Every sprite the content references exists, as a grid or an override PNG.
func _validate_sprite_refs() -> PackedStringArray:
	var problems: PackedStringArray = []
	var refs: Dictionary[String, String] = {}
	for id in REQUIRED_SPRITES:
		refs[id] = "used by the UI"
	for mode_entry in modes():
		_add_sprite_ref(refs, mode_entry.get("icon"), "%s mode '%s'"
				% [CATALOG_FILE, mode_entry.get("id", "?")])
		for game_entry in _dicts(mode_entry.get("games")):
			_add_sprite_ref(refs, game_entry.get("icon"), "%s game '%s'"
					% [CATALOG_FILE, game_entry.get("id", "?")])
	for entry in objects():
		_add_sprite_ref(refs, entry.get("sprite"), "%s object '%s'"
				% [OBJECTS_FILE, entry.get("id", "?")])
	for entry in _dicts(_words.get("words")):
		_add_sprite_ref(refs, entry.get("picture"), "%s word '%s'"
				% [_words_file, entry.get("id", "?")])
	for id in refs:
		if not sprite_exists(id):
			problems.append("sprites: no sprite '%s' (%s): no grid in sprites/*.json and no %s"
					% [id, refs[id], sprite_override_path(id)])
	return problems


static func _add_sprite_ref(refs: Dictionary[String, String], id: Variant, where: String) -> void:
	if id is String and not String(id).is_empty() and not refs.has(id):
		refs[id] = where


func _validate_font() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _font.is_empty():
		return problems
	var f := FONT_FILE
	var height_value: Variant = _font.get("height")
	if not (_is_int_like(height_value) and int(height_value) >= 1):
		problems.append("%s: 'height' must be a positive integer" % f)
		return problems
	var height := int(height_value)
	var baseline: Variant = _font.get("baseline")
	if not (_is_int_like(baseline) and int(baseline) >= 1 and int(baseline) <= height):
		problems.append("%s: 'baseline' must be an integer 1-%d" % [f, height])
	var spacing: Variant = _font.get("spacing", 1)
	if not (_is_int_like(spacing) and int(spacing) >= 0):
		problems.append("%s: 'spacing' must be an integer >= 0" % f)
	var glyphs: Variant = _font.get("glyphs")
	if not (glyphs is Dictionary and not (glyphs as Dictionary).is_empty()):
		problems.append("%s: 'glyphs' must be a non-empty object" % f)
		return problems
	for key: Variant in glyphs:
		var label := "glyph '%s'" % key
		if String(key).length() != 1:
			problems.append("%s: %s: the key must be a single character" % [f, label])
			continue
		var problem := _check_glyph(glyphs[key], height)
		if not problem.is_empty():
			problems.append("%s: %s: %s" % [f, label, problem])
	return problems


## "" when a glyph is `height` rows of '#'/'.' of one length with at most
## `MAX_GLYPH_WIDTH` inked columns, or an object with such `rows` and/or a
## non-negative integer `advance`.
static func _check_glyph(entry: Variant, height: int) -> String:
	var rows: Variant = entry
	if entry is Dictionary:
		if entry.has("advance") and not (_is_int_like(entry["advance"]) and int(entry["advance"]) >= 0):
			return "'advance' must be an integer >= 0"
		if not entry.has("rows"):
			return "" if entry.has("advance") else "needs 'rows' or 'advance'"
		rows = entry["rows"]
	if not rows is Array:
		return "must be a list of rows, or an object with 'rows' and/or 'advance'"
	if (rows as Array).size() != height:
		return "has %d rows, the font height is %d" % [(rows as Array).size(), height]
	var length := -1
	var width := 0
	for row: Variant in rows:
		if not row is String:
			return "every row must be a string"
		if length >= 0 and String(row).length() != length:
			return "rows have different lengths"
		length = String(row).length()
		for character in String(row):
			if not GLYPH_PIXELS.contains(character):
				return "rows may only contain '#' and '.', found '%s'" % character
		width = maxi(width, String(row).rfind("#") + 1)
	if width > MAX_GLYPH_WIDTH:
		return "is %d pixels wide, at most %d" % [width, MAX_GLYPH_WIDTH]
	return ""


## Every character the game draws has a glyph.
func _validate_glyph_coverage() -> PackedStringArray:
	var problems: PackedStringArray = []
	if _font.is_empty() or not _font.get("glyphs") is Dictionary:
		return problems
	var missing: PackedStringArray = []
	for character in required_glyph_chars():
		if not has_glyph(character):
			missing.append("'%s'" % character)
	if not missing.is_empty():
		problems.append("%s: no glyph for %s (used by the words or the alphabet in either case, the digits and signs, or the UI strings)"
				% [FONT_FILE, ", ".join(missing)])
	return problems


# --- helpers ---------------------------------------------------------------------

func _palette_names() -> Dictionary[String, bool]:
	var names: Dictionary[String, bool] = {}
	var colors: Variant = _palette.get("colors")
	if colors is Dictionary:
		for entry: Variant in colors.values():
			if entry is Dictionary and entry.get("name") is String:
				names[entry["name"]] = true
	return names


## The valid blank indices of a word: its `blank` list, or every index.
static func _blank_indices(entry: Dictionary, length: int) -> Array[int]:
	var indices: Array[int] = []
	if entry.has("blank"):
		for value: Variant in entry["blank"]:
			indices.append(int(value))
	else:
		for i in length:
			indices.append(i)
	return indices


## "" when `blank` is a non-empty list of unique integer indices into the word.
static func _check_blank(blank: Variant, length: int) -> String:
	if not (blank is Array and not (blank as Array).is_empty()):
		return "'blank' must be a non-empty array of letter indices"
	var seen: Array[int] = []
	for value: Variant in blank:
		if not (_is_int_like(value) and int(value) >= 0 and int(value) < length):
			return "'blank' has an invalid index %s" % [value]
		if seen.has(int(value)):
			return "'blank' repeats index %d" % int(value)
		seen.append(int(value))
	return ""


static func _chars_outside(text: String, alphabet: PackedStringArray) -> PackedStringArray:
	var outside: PackedStringArray = []
	for letter in text:
		if not alphabet.has(letter) and not outside.has(letter):
			outside.append(letter)
	return outside


static func _check_id(file: String, label: String, id: Variant,
		seen: Dictionary[String, bool]) -> PackedStringArray:
	if not id is String or String(id).is_empty():
		return PackedStringArray(["%s: %s: missing 'id'" % [file, label]])
	if not _is_id(id):
		return PackedStringArray(["%s: %s: the id must be lowercase snake_case" % [file, label]])
	if seen.has(id):
		return PackedStringArray(["%s: %s: duplicate id" % [file, label]])
	seen[id] = true
	return PackedStringArray()


static func _check_strings(file: String, label: String, entry: Dictionary,
		keys: PackedStringArray) -> PackedStringArray:
	var problems: PackedStringArray = []
	for key in keys:
		var value: Variant = entry.get(key)
		if not (value is String and not String(value).is_empty()):
			problems.append("%s: %s: missing '%s'" % [file, label, key])
	return problems


static func _label(kind: String, entry: Dictionary, index: int) -> String:
	var id: Variant = entry.get("id")
	if id is String and not String(id).is_empty():
		return "%s '%s'" % [kind, id]
	return "%s #%d" % [kind, index + 1]


## Lowercase snake_case: a-z first, then a-z, 0-9 or _.
static func _is_id(value: Variant) -> bool:
	if not value is String or String(value).is_empty():
		return false
	var text := String(value)
	if not _ID_FIRST_CHARS.contains(text[0]):
		return false
	for letter in text:
		if not _ID_CHARS.contains(letter):
			return false
	return true


## True when a JSON value is this exact string. Comparing a non-string Variant to a
## String with == is a script error, so every lookup goes through here.
static func _is_text(value: Variant, text: String) -> bool:
	return value is String and value == text


static func _is_color(value: Variant) -> bool:
	return value is String and String(value).begins_with("#") and Color.html_is_valid(value)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_positive(value: Variant) -> bool:
	return _is_number(value) and float(value) > 0.0


## JSON numbers parse as floats, so 10.0 counts as an integer.
static func _is_int_like(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and float(value) == floorf(value))


static func _is_notes(notes: Variant) -> bool:
	if not (notes is Array and not (notes as Array).is_empty()):
		return false
	for note: Variant in notes:
		if not (note is Array and (note as Array).size() == 2
				and _is_positive(note[0]) and _is_positive(note[1])):
			return false
	return true


## The Dictionary entries of a JSON array, typed; empty for anything else.
static func _dicts(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				result.append(entry)
	return result
