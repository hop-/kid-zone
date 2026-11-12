extends MiniGame
## Math, addition: `a + b = ?`, with `a` and `b` identical objects (fruit, vegetable
## or toy) drawn in rows of 5 above their numbers, and the answer tapped from 4
## `ChoiceButton`s. Questions come from `AdditionGenerator` with the level params
## (`max_sum` and/or `max_addend`).

const CHOICE_SCENE := preload("res://ui/choice_button.tscn")
const CHOICE_SIZE := Vector2(48, 36)
## Objects per row in a group.
const ROW_LENGTH := 5
const BLANK_TEXT := "?"
const BLANK_COLOR := "highlight"
const ANSWER_COLOR := "green"

var _generator: AdditionGenerator = null
## Object id -> sprite id.
var _object_sprites: Dictionary[String, String] = {}
var _question: Dictionary = {}

@onready var _group_a: GridContainer = %GroupA
@onready var _group_b: GridContainer = %GroupB
@onready var _number_a: Label = %NumberA
@onready var _number_b: Label = %NumberB
@onready var _blank: Label = %Blank
@onready var _choices: HBoxContainer = %Choices


func setup(params: Dictionary, rng: RandomNumberGenerator) -> void:
	_object_sprites.clear()
	for entry in Content.objects():
		var object_id := str(entry.get("id", ""))
		_object_sprites[object_id] = str(entry.get("sprite", object_id))
	_generator = AdditionGenerator.new(params, Content.object_ids(), rng)


func next_question() -> Dictionary:
	return _generator.generate() if _generator != null else {}


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
	var values: Array = question.get("choices", [])
	_set_button_count(values.size())
	for i in values.size():
		var button := choice_buttons()[i]
		button.reset()
		button.value = int(values[i])


func show_wrong(value: Variant) -> void:
	var button := _button_for(value)
	if button != null:
		await button.show_wrong()
	feedback_done.emit()


func show_correct() -> void:
	var answer: Variant = _question.get("answer")
	_blank.text = str(answer)
	_blank.add_theme_color_override(&"font_color", Art.theme_color(ANSWER_COLOR))
	var button := _button_for(answer)
	hop(_blank)
	if button != null:
		await button.show_correct()
	feedback_done.emit()


## The answer buttons, in screen order.
func choice_buttons() -> Array[ChoiceButton]:
	var buttons: Array[ChoiceButton] = []
	for child in _choices.get_children():
		if child is ChoiceButton and not child.is_queued_for_deletion():
			buttons.append(child)
	return buttons


## How many objects each group shows: [a, b].
func object_counts() -> Array[int]:
	return [_group_a.get_child_count(), _group_b.get_child_count()]


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


func _set_button_count(count: int) -> void:
	var buttons := choice_buttons()
	for i in range(count, buttons.size()):
		_choices.remove_child(buttons[i])
		buttons[i].queue_free()
	for i in range(buttons.size(), count):
		var button := CHOICE_SCENE.instantiate() as ChoiceButton
		button.custom_minimum_size = CHOICE_SIZE
		button.chosen.connect(choice_made.emit)
		_choices.add_child(button)


func _button_for(value: Variant) -> ChoiceButton:
	for button in choice_buttons():
		if typeof(button.value) == typeof(value) and button.value == value:
			return button
	return null
