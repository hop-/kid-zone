extends Control
## Root of the game. `ScreenHost` holds the current screen and `Fade` covers it
## during transitions; the `Router` autoload drives both and opens the main menu.
##
## Debug and capture helpers, read from the user args after `--` (they work in debug
## and release builds and never write any data: the settings file is not saved while
## one of them is active):
## - `--smoke-test`: checks the content, the pixel font, the theme, every sprite, every
##   sound effect and every screen and game scene, then prints `SMOKE OK` and exits 0,
##   or prints the problems and exits 1.
## - `--open=<game_id>[:<level_id>]` with an optional `--seed=<n>`: opens that game
##   directly (the first level when the game has levels and none is given), with the
##   back stack a kid would have (main menu, mode menu, level select).
## - `--screen=<screen>`: opens `main_menu`, `mode_menu:<mode_id>`,
##   `level_select:<game_id>` or `round_end[:<game_id>[:<level_id>]]` (round end shows
##   a sample of gold and silver stars).
## Bad arguments print the problem and the usage, and exit 1.

const USAGE := "usage: godot --path . -- [--smoke-test | --open=<game_id>[:<level_id>] " \
		+ "[--seed=<n>] | --screen=main_menu|mode_menu:<mode_id>|level_select:<game_id>" \
		+ "|round_end[:<game_id>[:<level_id>]]]"
const SMOKE_OK := "SMOKE OK"
const SCREEN_IDS: PackedStringArray = ["main_menu", "mode_menu", "level_select", "round_end"]

@onready var screen_host: Control = $ScreenHost
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	for warning: String in args["warnings"]:
		push_warning("main: %s" % warning)
	if not (args["errors"] as PackedStringArray).is_empty():
		_fail(args["errors"])
		return
	if args["smoke_test"] or args["open"] != "" or args["screen"] != "":
		# Debug sessions must not change the player's saved settings.
		Settings.path = ""
	if args["smoke_test"]:
		_run_smoke_test()
		return
	Router.attach(screen_host, fade)
	if args["open"] != "" or args["screen"] != "":
		var plan := _debug_stack(args)
		var problems: PackedStringArray = plan["errors"]
		if problems.is_empty() and not _open_stack(plan["stack"]):
			problems.append("could not open %s" % [plan["stack"]])
		if not problems.is_empty():
			_fail(problems)
			return
		var shell := Router.current_screen() as GameShell
		print("debug: opened %s%s" % [" > ".join(Router.stack_ids()),
				" (seed %d)" % shell.get_seed() if shell != null else ""])
		return
	Router.home()


func _exit_tree() -> void:
	Router.detach()


# --- arguments -------------------------------------------------------------------

## Parses the user args (after `--`) into
## `{smoke_test: bool, open: String, level: String, seed: Variant (int or null),
## screen: String, screen_args: PackedStringArray, errors: PackedStringArray,
## warnings: PackedStringArray}`. Only the syntax is checked here; the ids are checked
## against the catalog when the screens are opened.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var result := {
		"smoke_test": false, "open": "", "level": "", "seed": null,
		"screen": "", "screen_args": PackedStringArray(),
		"errors": PackedStringArray(), "warnings": PackedStringArray(),
	}
	var errors: PackedStringArray = result["errors"]
	var warnings: PackedStringArray = result["warnings"]
	for arg in args:
		if arg == "--smoke-test":
			result["smoke_test"] = true
		elif arg.begins_with("--open="):
			var parts := arg.trim_prefix("--open=").split(":")
			if parts.size() > 2 or parts[0].is_empty() or (parts.size() == 2 and parts[1].is_empty()):
				errors.append("bad %s: expected --open=<game_id>[:<level_id>]" % arg)
				continue
			result["open"] = parts[0]
			result["level"] = parts[1] if parts.size() == 2 else ""
		elif arg.begins_with("--seed="):
			var value := arg.trim_prefix("--seed=")
			if not value.is_valid_int():
				errors.append("bad %s: the seed must be an integer" % arg)
				continue
			result["seed"] = value.to_int()
		elif arg.begins_with("--screen="):
			var parts := arg.trim_prefix("--screen=").split(":")
			if parts[0] not in SCREEN_IDS or "" in parts:
				errors.append("bad %s: expected one of main_menu, mode_menu:<mode_id>, "
						% arg + "level_select:<game_id>, round_end[:<game_id>[:<level_id>]]")
				continue
			result["screen"] = parts[0]
			parts.remove_at(0)
			result["screen_args"] = parts
		else:
			warnings.append("ignoring unknown argument '%s'" % arg)
	var modes := int(result["smoke_test"]) + int(result["open"] != "") + int(result["screen"] != "")
	if modes > 1:
		errors.append("use only one of --smoke-test, --open and --screen")
	if result["seed"] != null and result["open"] == "" and errors.is_empty():
		warnings.append("--seed only applies to --open; ignoring it")
	return result


# --- direct screens --------------------------------------------------------------

## The screens to open, bottom first, for `--open` or `--screen`: the back stack a kid
## would have built by tapping there. Returns `{stack: Array[Dictionary] of
## {id, params}, errors: PackedStringArray}`.
func _debug_stack(args: Dictionary) -> Dictionary:
	var errors: PackedStringArray = []
	var stack: Array[Dictionary] = [{"id": "main_menu", "params": {}}]
	var screen: String = args["screen"]
	var screen_args: PackedStringArray = args["screen_args"]
	if args["open"] != "":
		var game_id: String = args["open"]
		var level_id := _resolve_level(game_id, args["level"], errors)
		if errors.is_empty():
			_add_game_path(stack, game_id)
			var params := {"game_id": game_id, "level_id": level_id}
			if args["seed"] != null:
				params["seed"] = args["seed"]
			stack.append({"id": "game", "params": params})
	elif screen == "main_menu":
		if not screen_args.is_empty():
			errors.append("--screen=main_menu takes no argument")
	elif screen == "mode_menu":
		if screen_args.size() != 1 or Content.mode(screen_args[0]).is_empty():
			errors.append("--screen=mode_menu:<mode_id> needs one of: %s" % ", ".join(_mode_ids()))
		else:
			stack.append({"id": "mode_menu", "params": {"mode_id": screen_args[0]}})
	elif screen == "level_select":
		if screen_args.size() != 1 or Content.levels_for(screen_args[0]).is_empty():
			errors.append("--screen=level_select:<game_id> needs a game with levels: %s"
					% ", ".join(_game_ids(true)))
		else:
			_add_game_path(stack, screen_args[0])
	elif screen == "round_end":
		if screen_args.size() > 2:
			errors.append("--screen=round_end takes at most <game_id>:<level_id>")
		else:
			var game_id := screen_args[0] if screen_args.size() >= 1 else _first_game_id()
			var level_id := _resolve_level(game_id,
					screen_args[1] if screen_args.size() == 2 else "", errors)
			if errors.is_empty():
				_add_game_path(stack, game_id)
				stack.append({"id": "round_end", "params": {
					"game_id": game_id, "level_id": level_id,
					"stars": sample_stars(Content.round_length(game_id)),
				}})
	return {"stack": stack, "errors": errors}


## Appends the mode menu and, for a game with levels, its level select.
func _add_game_path(stack: Array[Dictionary], game_id: String) -> void:
	stack.append({"id": "mode_menu", "params": {"mode_id": Content.mode_of(game_id)}})
	if not Content.levels_for(game_id).is_empty():
		stack.append({"id": "level_select", "params": {"game_id": game_id}})


## The level to play: `level_id` if the game has it, the first level when it is empty,
## "" for a game without levels. Adds to `errors` for an unknown game or level.
func _resolve_level(game_id: String, level_id: String, errors: PackedStringArray) -> String:
	if Content.game(game_id).is_empty():
		errors.append("unknown game '%s'; games: %s" % [game_id, ", ".join(_game_ids(false))])
		return ""
	var levels := Content.levels_for(game_id)
	if levels.is_empty():
		if not level_id.is_empty():
			errors.append("game '%s' has no levels" % game_id)
		return ""
	if level_id.is_empty():
		return str(levels[0].get("id", ""))
	if Content.level(game_id, level_id).is_empty():
		var ids: PackedStringArray = []
		for entry in levels:
			ids.append(str(entry.get("id", "")))
		errors.append("game '%s' has no level '%s'; levels: %s" % [game_id, level_id, ", ".join(ids)])
	return level_id


## A fixed round result for screenshots: gold stars with every fourth one silver.
static func sample_stars(count: int) -> Array[int]:
	var stars: Array[int] = []
	for i in count:
		stars.append(RoundController.Star.SILVER if i % 4 == 3 else RoundController.Star.GOLD)
	return stars


## Opens `stack` screen by screen with no fade, then restores the fade duration.
func _open_stack(stack: Array[Dictionary]) -> bool:
	var saved_fade := Router.fade_duration
	Router.fade_duration = 0.0
	var opened := Router.home()
	for i in range(1, stack.size()):
		if not opened:
			break
		opened = Router.go_to(stack[i]["id"], stack[i]["params"])
	Router.fade_duration = saved_fade
	return opened


func _mode_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for entry in Content.modes():
		ids.append(str(entry.get("id", "")))
	return ids


func _game_ids(with_levels_only: bool) -> PackedStringArray:
	var ids: PackedStringArray = []
	for mode_id in _mode_ids():
		for entry in Content.games_for(mode_id):
			var game_id := str(entry.get("id", ""))
			if not with_levels_only or not Content.levels_for(game_id).is_empty():
				ids.append(game_id)
	return ids


func _first_game_id() -> String:
	var ids := _game_ids(false)
	return ids[0] if not ids.is_empty() else ""


# --- smoke test ------------------------------------------------------------------

func _run_smoke_test() -> void:
	var problems := smoke_problems()
	if not problems.is_empty():
		_fail(problems, "SMOKE FAILED")
		return
	print(SMOKE_OK)
	get_tree().quit(0)


## Everything the smoke test checks; empty means the build is good. Uses the
## autoloads, so it checks exactly what the game would use.
static func smoke_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	for problem in Content.validate():
		problems.append("content: %s" % problem)

	var font := Art.font()
	if not font is FontFile or font == ThemeDB.fallback_font:
		problems.append("font: the pixel font could not be built from font.json")
	else:
		for character in Content.required_glyph_chars():
			if character != " " and not font.has_char(character.unicode_at(0)):
				problems.append("font: no glyph for '%s'" % character)
	var theme := Art.theme()
	if theme == null or theme.default_font != font:
		problems.append("theme: the UI theme does not use the pixel font")

	for sprite_id in Content.sprite_ids():
		var texture := Art.sprite(sprite_id)
		var size: Variant = Content.sprite_grid(sprite_id).get("size")
		if texture == null:
			problems.append("sprite '%s': no texture" % sprite_id)
		elif not Art.is_overridden(sprite_id) and size is Array and (size as Array).size() == 2 \
				and texture.get_size() != Vector2(size[0], size[1]):
			problems.append("sprite '%s': built %s, expected %s" % [sprite_id, texture.get_size(), size])

	for sound_id in Content.sound_ids():
		var stream := Audio.sfx_stream(sound_id)
		if stream == null or stream.get_length() <= 0.0:
			problems.append("sound '%s': could not be synthesized or loaded" % sound_id)

	var scene_paths: Dictionary[String, String] = Router.DEFAULT_SCENES.duplicate()
	for mode_entry in Content.modes():
		for game_entry in Content.games_for(str(mode_entry.get("id", ""))):
			scene_paths["game '%s'" % game_entry.get("id", "?")] = str(game_entry.get("scene", ""))
	for label in scene_paths:
		var scene := load(scene_paths[label]) as PackedScene if ResourceLoader.exists(scene_paths[label]) else null
		if scene == null or not scene.can_instantiate():
			problems.append("scene %s: cannot load %s" % [label, scene_paths[label]])
		elif label.begins_with("game "):
			var node := scene.instantiate()
			if not node is MiniGame:
				problems.append("scene %s: the root of %s is not a MiniGame" % [label, scene_paths[label]])
			node.free()
	return problems


## Prints `problems` (with the usage for argument errors) and quits with exit code 1.
func _fail(problems: PackedStringArray, title: String = "") -> void:
	if not title.is_empty():
		printerr(title)
	for problem in problems:
		printerr("  %s" % problem)
	if title.is_empty():
		printerr(USAGE)
	get_tree().quit(1)
