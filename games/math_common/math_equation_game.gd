class_name MathEquationGame
extends MiniGame
## The shared base of the math equation games: `a <op> b = ?`, with `a` and `b`
## identical objects (fruit, vegetable or toy) drawn in rows of 5 above their numbers,
## and the answer tapped from a `ChoiceRow`.
##
## Its scene is `math_equation.tscn`. A game inherits that scene, swaps the root
## script for its own script that extends this class, and overrides
## `_make_generator()` and `_operator_text()`. The generator returns
## `{a, b, answer, choices, object_id, ...}` from `generate()`.

const CHOICE_SIZE := Vector2(48, 36)
## Objects per row in a group.
const ROW_LENGTH := 5
const BLANK_TEXT := "?"
const BLANK_COLOR := "highlight"
const ANSWER_COLOR := "green"

## The question generator from `_make_generator()`; it has `generate() -> Dictionary`.
var _generator: RefCounted = null
## Object id -> sprite id.
var _object_sprites: Dictionary[String, String] = {}
var _question: Dictionary = {}

@onready var _group_a: GridContainer = %GroupA
@onready var _group_b: GridContainer = %GroupB
@onready var _number_a: Label = %NumberA
@onready var _number_b: Label = %NumberB
@onready var _operator: Label = %Operator
@onready var _blank: Label = %Blank
@onready var _choices: ChoiceRow = %Choices


func setup(params: Dictionary, rng: RandomNumberGenerator) -> void:
	_object_sprites.clear()
	for entry in Content.objects():
		var object_id := str(entry.get("id", ""))
		_object_sprites[object_id] = str(entry.get("sprite", object_id))
	_operator.text = _operator_text()
	_choices.chosen.connect(choice_made.emit)
	_generator = _make_generator(params, Content.object_ids(), rng)


func next_question() -> Dictionary:
	if _generator == null:
		return {}
	var question: Variant = _generator.call(&"generate")
	return question if question is Dictionary else {}


func present(question: Dictionary) -> void:
	_question = question
	var a := int(question.get("a", 0))
	var b := int(question.get("b", 0))
	var sprite := Art.sprite(_object_sprites.get(str(question.get("object_id", "")), ""))
	_fill_group(_group_a, a, sprite)
	_fill_group(_group_b, b, sprite)
	_number_a.text = str(a)
	_number_b.text = str(b)
	_blank.text = BLANK_TEXT
	_blank.add_theme_color_override(&"font_color", Art.theme_color(BLANK_COLOR))
	var values: Array = []
	for value: Variant in question.get("choices", []):
		values.append(int(value))
	_choices.set_choices(values, CHOICE_SIZE)


func show_wrong(value: Variant) -> void:
	await _choices.show_wrong(value)
	feedback_done.emit()


func show_correct() -> void:
	var answer: Variant = _question.get("answer")
	_blank.text = str(answer)
	_blank.add_theme_color_override(&"font_color", Art.theme_color(ANSWER_COLOR))
	hop(_blank)
	await _choices.show_correct(answer)
	feedback_done.emit()


## Virtual: the question generator for these level `params`, with the catalog's
## object ids and the round's RNG. It must have `generate() -> Dictionary`.
func _make_generator(_params: Dictionary, _object_ids: PackedStringArray,
		_rng: RandomNumberGenerator) -> RefCounted:
	_not_overridden("_make_generator")
	return null


## Virtual: the operator sign shown between the numbers, such as "+".
func _operator_text() -> String:
	_not_overridden("_operator_text")
	return ""


func _fill_group(group: GridContainer, count: int, texture: Texture2D) -> void:
	for child in group.get_children():
		group.remove_child(child)
		child.queue_free()
	group.columns = clampi(count, 1, ROW_LENGTH)
	for i in count:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(rect)
