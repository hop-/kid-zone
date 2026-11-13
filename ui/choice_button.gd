class_name ChoiceButton
extends KidButton
## A big answer button (a number or a letter) for the games.
##
## It is idle (tappable) until `show_wrong()` (it shakes, turns grey and stays disabled
## until `reset()`) or `show_correct()` (green, a short hop, disabled).
## It plays `tap` on press and emits `chosen(value)` on release. `show_wrong()` and
## `show_correct()` can be awaited: they return when the animation ends. The wrong
## and correct sounds belong to the game shell.

## Emitted on release with this button's `value`.
signal chosen(value: Variant)
## Emitted when a wrong or correct animation ends, or is cut short by another one or
## `reset()`.
signal animation_done

const DEFAULT_SIZE := Vector2(40, 36)
## Horizontal shake offsets, one per step.
const SHAKE_OFFSETS: Array[int] = [-3, 3, -2, 2, -1, 1, 0]
const SHAKE_STEP := 0.04
const HOP_HEIGHT := 4
const HOP_TIME := 0.08
const CORRECT_COLOR := "green"

## The answer this button stands for; its text is `str(value)`.
var value: Variant = null:
	set(new_value):
		value = new_value
		text = "" if new_value == null else str(new_value)

var _tween: Tween = null
var _rest_position := Vector2.ZERO


func _init() -> void:
	super()
	custom_minimum_size = DEFAULT_SIZE
	theme_type_variation = &"ButtonLarge"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pressed.connect(_on_pressed)


## Back to idle: enabled, default colors, at rest.
func reset() -> void:
	_stop_animation()
	disabled = false
	_set_correct_style(false)


## Shakes, turns grey and disables the button. Await it to wait for the shake.
func show_wrong() -> void:
	_stop_animation()
	disabled = true
	_set_correct_style(false)
	_rest_position = position
	_tween = create_tween()
	for offset in SHAKE_OFFSETS:
		_tween.tween_property(self, ^"position:x", _rest_position.x + offset, SHAKE_STEP)
	_tween.finished.connect(_on_animation_finished)
	await animation_done


## Turns the button green, disables it and plays a short hop. Await it to wait for
## the hop.
func show_correct() -> void:
	_stop_animation()
	disabled = true
	_set_correct_style(true)
	_rest_position = position
	_tween = create_tween()
	_tween.tween_property(self, ^"position:y", _rest_position.y - HOP_HEIGHT, HOP_TIME)
	_tween.tween_property(self, ^"position:y", _rest_position.y, HOP_TIME)
	_tween.finished.connect(_on_animation_finished)
	await animation_done


func _on_pressed() -> void:
	chosen.emit(value)


func _stop_animation() -> void:
	if _tween == null:
		return
	_tween.kill()
	_tween = null
	position = _rest_position
	animation_done.emit()


func _on_animation_finished() -> void:
	_tween = null
	animation_done.emit()


func _set_correct_style(on: bool) -> void:
	if not on:
		remove_theme_stylebox_override(&"disabled")
		remove_theme_color_override(&"font_disabled_color")
		return
	add_theme_stylebox_override(&"disabled", Art.bevel_style(Content.color(CORRECT_COLOR)))
	add_theme_color_override(&"font_disabled_color", Art.theme_color("text_dark"))
