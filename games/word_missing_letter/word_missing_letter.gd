extends MiniGame
## Words, missing letter: a picture, its word as letter boxes with one blank
## (highlighted), and 4 letter buttons in a `ChoiceRow`. Questions come from
## `MissingLetterGenerator` with the locale's word pack (`Content.word_pack()`); the
## `choices` param sets how many letters are offered (default 4).
##
## Letters are shown in the player's letter case (`Settings.display_text()`, upper by
## default); the choice values stay the pack's lowercase letters, so answer checking
## doesn't depend on the case.

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
@onready var _choices: ChoiceRow = %Choices


func setup(params: Dictionary, rng: RandomNumberGenerator) -> void:
	_box_style = Art.bevel_style(Art.theme_color(BOX_COLOR))
	_blank_style = Art.bevel_style(Art.theme_color(BLANK_COLOR))
	_filled_style = Art.bevel_style(Art.theme_color(FILLED_COLOR))
	_choices.chosen.connect(choice_made.emit)
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
	var values: Array = []
	var texts: Array = []
	for value: Variant in question.get("choices", []):
		values.append(str(value))
		texts.append(Settings.display_text(str(value)))
	_choices.set_choices(values, CHOICE_SIZE, texts)


func show_wrong(value: Variant) -> void:
	await _choices.show_wrong(value)
	feedback_done.emit()


func show_correct() -> void:
	var answer := str(_question.get("answer", ""))
	var box := blank_box()
	if box != null:
		box.text = Settings.display_text(answer)
		box.add_theme_stylebox_override(&"normal", _filled_style)
		hop(box)
	await _choices.show_correct(answer)
	feedback_done.emit()


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
		box.text = "" if is_blank else Settings.display_text(text[i])
		box.add_theme_stylebox_override(&"normal", _blank_style if is_blank else _box_style)
		_letters.add_child(box)

