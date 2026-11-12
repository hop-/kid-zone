extends Node
## Screen navigation: a stack of screens shown one at a time in a host Control
## (`main.tscn`'s `ScreenHost`).
##
## - `go_to(screen_id, params, replace)` opens a screen on top of the stack (or in
##   place of the top one), `back()` pops one screen and `home()` returns to the main
##   menu. Each runs a short stepped fade (`fade_duration`, about 0.2 s) on the `Fade`
##   rect, which blocks input while it runs; calls made during a transition are
##   ignored, so a double tap can't open two screens.
## - Back requests come from the on-screen back button, `ui_cancel` (Esc) and
##   Android's back (`NOTIFICATION_WM_GO_BACK_REQUEST`, with
##   `application/config/quit_on_go_back=false`). `back()` plays the `back` sound,
##   and does nothing on the main menu, so kids can't leave the app by accident.
## - Screens are scenes listed in `scenes` (id -> path). Only the top screen exists:
##   going back builds the previous screen again from its saved params. A screen gets
##   its params through `setup_screen(params: Dictionary)`, called before it enters
##   the tree, when its root script has that method.
##
## Registered as the last autoload. `main.gd` calls `attach()`. Tests can attach their
## own host Control, set `fade_duration = 0.0` (every call then switches screens
## immediately), stand in a scene for an id through `scenes`, and restore everything
## with `detach()`, `fade_duration = DEFAULT_FADE_DURATION` and
## `scenes = DEFAULT_SCENES.duplicate()`.

## Emitted when a new screen has entered the host.
signal screen_changed(screen_id: String)
## Emitted when a transition (including its fade) has finished.
signal transition_finished

const HOME_SCREEN := "main_menu"
## Screen ids -> scenes. `game` is the GameShell; it reads `game_id` and `level_id`.
const DEFAULT_SCENES: Dictionary[String, String] = {
	"main_menu": "res://screens/main_menu.tscn",
	"mode_menu": "res://screens/mode_menu.tscn",
	"level_select": "res://screens/level_select.tscn",
	"game": "res://core/game_shell.tscn",
	"round_end": "res://screens/round_end.tscn",
}
## The whole transition (fade out + fade in), in seconds.
const DEFAULT_FADE_DURATION := 0.2
## Alpha steps per half of the fade, for an 8-bit look.
const FADE_STEPS := 4
const BACK_SFX := "back"

var scenes: Dictionary[String, String] = DEFAULT_SCENES.duplicate()
## Zero or less switches screens immediately, with no fade.
var fade_duration: float = DEFAULT_FADE_DURATION

var _host: Control = null
var _fade: ColorRect = null
## Entries {"id": String, "params": Dictionary}; the last one is on screen.
var _stack: Array[Dictionary] = []
var _screen: Control = null
var _transitioning := false
var _tween: Tween = null


## Shows screens in `host`, fading with `fade` (optional). Clears any previous host's
## screen and the stack; call `home()` or `go_to()` next.
func attach(host: Control, fade: ColorRect = null) -> void:
	detach()
	_host = host
	_fade = fade
	if _fade != null:
		_fade.color = Art.theme_color("black")
		_set_fade_alpha(0.0)


## Frees the current screen, clears the stack and forgets the host. Until the next
## `attach()`, `back()` does nothing and `go_to()`/`home()` report an error.
func detach() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_transitioning = false
	if is_instance_valid(_fade):
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_fade_alpha(0.0)
	if is_instance_valid(_screen):
		_screen.queue_free()
		if _screen.get_parent() != null:
			_screen.get_parent().remove_child(_screen)
	_screen = null
	_stack.clear()
	_host = null
	_fade = null


func is_attached() -> bool:
	return is_instance_valid(_host)


## The id of the screen on top of the stack; "" when there is none.
func current_id() -> String:
	return "" if _stack.is_empty() else String(_stack.back()["id"])


## The params the current screen was opened with (a copy).
func current_params() -> Dictionary:
	return {} if _stack.is_empty() else (_stack.back()["params"] as Dictionary).duplicate(true)


## The current screen node; null when there is none.
func current_screen() -> Control:
	return _screen if is_instance_valid(_screen) else null


## The stack's screen ids, bottom first.
func stack_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for entry in _stack:
		ids.append(String(entry["id"]))
	return ids


func is_transitioning() -> bool:
	return _transitioning


## Opens `screen_id` with `params` on top of the stack, or in place of the current
## screen when `replace` is true (round end replaces the game; "again" replaces round
## end). Returns false, changing nothing, when not attached, during a transition, or
## for an unknown id or missing scene.
func go_to(screen_id: String, params: Dictionary = {}, replace: bool = false) -> bool:
	if not _can_navigate("go_to('%s')" % screen_id):
		return false
	var scene := _scene_for(screen_id)
	if scene == null:
		return false
	var stack := _stack.duplicate()
	if replace and not stack.is_empty():
		stack.pop_back()
	stack.append({"id": screen_id, "params": params.duplicate(true)})
	_transition(stack, scene)
	return true


## Goes back one screen and plays the `back` sound. Returns false, changing nothing,
## on the bottom screen (the main menu), during a transition, or when not attached.
func back() -> bool:
	if _stack.size() < 2 or not _can_navigate("back()", false):
		return false
	var stack := _stack.duplicate()
	stack.pop_back()
	var entry: Dictionary = stack.back()
	var scene := _scene_for(String(entry["id"]))
	if scene == null:
		return false
	Audio.play_sfx(BACK_SFX)
	_transition(stack, scene)
	return true


## Clears the stack and opens the main menu. Returns false when the main menu is
## already the only screen, during a transition, or when not attached.
func home() -> bool:
	if current_id() == HOME_SCREEN and _stack.size() == 1:
		return false
	if not _can_navigate("home()"):
		return false
	var scene := _scene_for(HOME_SCREEN)
	if scene == null:
		return false
	var stack: Array[Dictionary] = [{"id": HOME_SCREEN, "params": {}}]
	_transition(stack, scene)
	return true


# --- back inputs -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel", false, true) and is_attached():
		get_viewport().set_input_as_handled()
		back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


# --- transitions -----------------------------------------------------------------

func _can_navigate(action: String, report: bool = true) -> bool:
	if not is_attached():
		if report:
			push_error("Router: %s before attach()" % action)
		return false
	return not _transitioning


func _scene_for(screen_id: String) -> PackedScene:
	if not scenes.has(screen_id):
		push_error("Router: unknown screen '%s'" % screen_id)
		return null
	var path: String = scenes[screen_id]
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	if scene == null:
		push_error("Router: screen '%s' has no scene at %s" % [screen_id, path])
	return scene


func _transition(stack: Array[Dictionary], scene: PackedScene) -> void:
	var half := fade_duration * 0.5
	if half <= 0.0 or not is_instance_valid(_fade):
		_show(stack, scene)
		transition_finished.emit()
		return
	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.visible = true
	_tween = create_tween()
	if _screen != null:
		_tween.tween_method(_set_fade_alpha, 0.0, 1.0, half)
	else:
		_set_fade_alpha(1.0)
	_tween.tween_callback(_show.bind(stack, scene))
	_tween.tween_method(_set_fade_alpha, 1.0, 0.0, half)
	_tween.tween_callback(_end_transition)


func _end_transition() -> void:
	_tween = null
	_transitioning = false
	if is_instance_valid(_fade):
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_fade_alpha(0.0)
	transition_finished.emit()


## Replaces the current screen with a new instance of `scene`, set up with the top
## entry's params.
func _show(stack: Array[Dictionary], scene: PackedScene) -> void:
	if not is_attached():
		return
	if is_instance_valid(_screen):
		_host.remove_child(_screen)
		_screen.queue_free()
	_stack = stack
	var entry: Dictionary = _stack.back()
	var node := scene.instantiate()
	var screen := node as Control
	if screen == null:
		push_error("Router: screen '%s' is not a Control" % entry["id"])
		node.free()
		_screen = null
		return
	if screen.has_method(&"setup_screen"):
		screen.call(&"setup_screen", (entry["params"] as Dictionary).duplicate(true))
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = screen
	_host.add_child(screen)
	screen_changed.emit(String(entry["id"]))


## Sets the fade's alpha in `FADE_STEPS` steps.
func _set_fade_alpha(value: float) -> void:
	if not is_instance_valid(_fade):
		return
	var color := _fade.color
	color.a = snappedf(clampf(value, 0.0, 1.0), 1.0 / FADE_STEPS)
	_fade.color = color
	# Stay visible (and blocking) for the whole transition, even at alpha 0.
	_fade.visible = color.a > 0.0 or _transitioning
