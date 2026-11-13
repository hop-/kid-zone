class_name StarBar
extends GridContainer
## A row (or grid) of star slots, each empty, gold or silver
## (`RoundController.Star`). The game shell shows 10 in one row; round end shows them
## bigger in two rows and fills them with `reveal()`.

## Emitted when `reveal()` has shown every star, or when a running reveal is cancelled.
signal revealed

const SLOT_SPRITES: Dictionary[int, String] = {
	RoundController.Star.EMPTY: "icon_star_empty",
	RoundController.Star.GOLD: "icon_star_gold",
	RoundController.Star.SILVER: "icon_star_silver",
}
const DEFAULT_SLOTS := 10
## `reveal()`: seconds between stars, and the pitch rise per star (a semitone).
const REVEAL_STEP := 0.15
const REVEAL_PITCH_STEP := 1.0594631
const REVEAL_SFX := "tap"

## How many slots there are.
@export var slot_count: int = DEFAULT_SLOTS:
	set(value):
		slot_count = maxi(0, value)
		_rebuild()
## Each star sprite is drawn at this integer scale.
@export var slot_scale: int = 1:
	set(value):
		slot_scale = maxi(1, value)
		_rebuild()

var _stars: Array[int] = []
var _reveal_tween: Tween = null


func _init() -> void:
	columns = DEFAULT_SLOTS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"h_separation", 1)
	add_theme_constant_override(&"v_separation", 1)


func _ready() -> void:
	_rebuild()


## The star in slot `index` (`RoundController.Star`).
func get_star(index: int) -> int:
	return _stars[index] if index >= 0 and index < _stars.size() else RoundController.Star.EMPTY


func set_star(index: int, star: int) -> void:
	if index < 0 or index >= slot_count:
		push_error("StarBar: no slot %d" % index)
		return
	_stars[index] = star if SLOT_SPRITES.has(star) else RoundController.Star.EMPTY
	_refresh_slot(index)


## Sets the first stars from `stars` and empties the rest. Cancels a running reveal.
func set_stars(stars: Array[int]) -> void:
	_cancel_reveal()
	for i in slot_count:
		set_star(i, stars[i] if i < stars.size() else RoundController.Star.EMPTY)


## Empties every slot.
func clear() -> void:
	set_stars([])


## Empties the slots, then fills them from `stars` one at a time, `step` seconds
## apart, with a rising `tap` and a little pop. Await it, or wait for `revealed`.
## `step` 0 fills them at once. `set_stars()`, `clear()` or another `reveal()` cancel a
## running reveal; it still emits `revealed`, so its awaiting caller always resumes.
func reveal(stars: Array[int], step: float = REVEAL_STEP) -> void:
	clear()
	var count := mini(stars.size(), slot_count)
	if step <= 0.0:
		set_stars(stars)
		revealed.emit()
		return
	# A tween owned by this node stops when the node is freed, so nothing resumes
	# on a dead instance.
	_reveal_tween = create_tween()
	for i in count:
		_reveal_tween.tween_interval(step)
		_reveal_tween.tween_callback(_reveal_star.bind(i, stars[i]))
	_reveal_tween.tween_callback(_finish_reveal)
	await revealed


func _reveal_star(index: int, star: int) -> void:
	set_star(index, star)
	Audio.play_sfx(REVEAL_SFX, pow(REVEAL_PITCH_STEP, index))
	_pop(index)


func _finish_reveal() -> void:
	_reveal_tween = null
	revealed.emit()


## Stops a running reveal and emits `revealed` for the caller awaiting it.
func _cancel_reveal() -> void:
	if _reveal_tween == null:
		return
	_reveal_tween.kill()
	_reveal_tween = null
	revealed.emit()


func _rebuild() -> void:
	var old_count := _stars.size()
	_stars.resize(slot_count)
	for i in range(old_count, slot_count):
		_stars[i] = RoundController.Star.EMPTY
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for i in slot_count:
		var rect := TextureRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(rect)
	for i in slot_count:
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	if index >= get_child_count():
		return
	var rect := get_child(index) as TextureRect
	rect.texture = Art.sprite(SLOT_SPRITES[_stars[index]])
	rect.custom_minimum_size = rect.texture.get_size() * slot_scale


func _pop(index: int) -> void:
	var rect := get_child(index) as TextureRect
	rect.pivot_offset = rect.size * 0.5
	rect.scale = Vector2(1.5, 1.5)
	var tween := rect.create_tween()
	tween.tween_property(rect, ^"scale", Vector2.ONE, REVEAL_STEP * 0.8) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
