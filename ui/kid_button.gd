class_name KidButton
extends Button
## The base of every Kid Zone button: it plays a sound on press, acts on release
## (the default `action_mode`, so dragging off the button cancels), takes no keyboard
## focus, and can grow its touch area past its drawn rect with `touch_margin`, so a
## small 24×24 button still has a 32×32 target.

## The sound played when the button goes down; "" plays nothing.
@export var press_sfx: String = "tap"
## Extra touch area on every side, in virtual pixels. Hits are accepted in the drawn
## rect grown by this margin.
@export var touch_margin: int = 0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button_down.connect(_on_button_down)


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(touch_margin).has_point(point)


## The touch target's size: the drawn size plus `touch_margin` on every side.
func touch_size() -> Vector2:
	return size + Vector2.ONE * (2 * touch_margin)


func _on_button_down() -> void:
	if not press_sfx.is_empty():
		Audio.play_sfx(press_sfx)
