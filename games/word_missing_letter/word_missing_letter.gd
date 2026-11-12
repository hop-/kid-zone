extends MiniGame
## Words, missing letter: a picture, its word as letter boxes with one blank
## (highlighted), and 4 letter `ChoiceButton`s. Questions come from
## `MissingLetterGenerator` with the locale's word pack (`Content.word_pack()`); the
## `choices` param sets how many letters are offered (default 4).

const CHOICE_SCENE := preload("res://ui/choice_button.tscn")
const CHOICE_SIZE := Vector2(40, 40)
const DEFAULT_CHOICES := 4
const LETTER_BOX_SIZE := Vector2(28, 32)
## Integer scale of the word picture (24×24 sprites drawn at 48×48).
const PICTURE_SCALE := 2
## Palette roles or names of the letter boxes.
const BOX_COLOR := "button"
const BLANK_COLOR := "highlight"
const FILLED_COLOR := "green"

var _generator: MissingLetterGenerator = null
var _question: Dictionary = {}
var _box_style: StyleBox = null
var _blank_style: StyleBox = null
var _filled_style: StyleBox = null

@onready var _picture: TextureRect = %Picture
@onready var _letters: HBoxContainer = %Letters
@onready var _choices: HBoxContainer = %Choices


func setup(params: Dictionary, rng: RandomNumberGenerator) -> void:
	_box_style = Art.bevel_style(Art.theme_color(BOX_COLOR))
	_blank_style = Art.bevel_style(Art.theme_color(BLANK_COLOR))
	_filled_style = Art.bevel_style(Art.theme_color(FILLED_COLOR))
	var choice_count := int(params.get("choices", DEFAULT_CHOICES))
	_generator = MissingLetterGenerator.new(Content.word_pack(), rng, choice_count)


func next_question() -> Dictionary:
	return _generator.generate() if _generator != null else {}


func present(question: Dictionary) -> void:
	_question = question
	var texture := Art.sprite(str(question.get("picture", "")))
	_picture.texture = texture
	_picture.custom_minimum_size = texture.get_size() * PICTURE_SCALE
	_build_letters(str(question.get("text", "")), int(question.get("blank_index", -1)))
	var values: Array = question.get("choices", [])
	_set_button_count(values.size())
	for i in values.size():
		var button := choice_buttons()[i]
		button.reset()
		button.value = str(values[i])


func show_wrong(value: Variant) -> void:
	var button := _button_for(value)
	if button != null:
		await button.show_wrong()
	feedback_done.emit()


func show_correct() -> void:
	var answer := str(_question.get("answer", ""))
	var box := blank_box()
	if box != null:
		box.text = answer
		box.add_theme_stylebox_override(&"normal", _filled_style)
		hop(box)
	var button := _button_for(answer)
	if button != null:
		await button.show_correct()
	feedback_done.emit()


## The letter buttons, in screen order.
func choice_buttons() -> Array[ChoiceButton]:
	var buttons: Array[ChoiceButton] = []
	for child in _choices.get_children():
		if child is ChoiceButton and not child.is_queued_for_deletion():
			buttons.append(child)
	return buttons


## The word's letter boxes, in order; the blank one shows "" until it's filled.
func letter_boxes() -> Array[Label]:
	var boxes: Array[Label] = []
	for child in _letters.get_children():
		if child is Label and not child.is_queued_for_deletion():
			boxes.append(child)
	return boxes


## The blank letter box; null before the first question.
func blank_box() -> Label:
	var boxes := letter_boxes()
	var index := int(_question.get("blank_index", -1))
	return boxes[index] if index >= 0 and index < boxes.size() else null


func _build_letters(text: String, blank_index: int) -> void:
	for child in _letters.get_children():
		_letters.remove_child(child)
		child.queue_free()
	for i in text.length():
		var box := Label.new()
		box.custom_minimum_size = LETTER_BOX_SIZE
		box.theme_type_variation = Art.LABEL_LARGE
		box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_theme_color_override(&"font_color", Art.theme_color("text_dark"))
		var is_blank := i == blank_index
		box.text = "" if is_blank else text[i]
		box.add_theme_stylebox_override(&"normal", _blank_style if is_blank else _box_style)
		_letters.add_child(box)


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
