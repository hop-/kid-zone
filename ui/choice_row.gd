class_name ChoiceRow
extends HBoxContainer
## A centered row of `ChoiceButton`s: the answer buttons of a game.
##
## `set_choices()` shows one button per value, reusing the buttons it already has.
## A tap on any button emits `chosen(value)`; connect it to the game's
## `choice_made.emit`. `show_wrong(value)` and `show_correct(value)` animate the
## button with that value and can be awaited.

## Emitted on release with the tapped button's `value`.
signal chosen(value: Variant)

const CHOICE_SCENE := preload("res://ui/choice_button.tscn")


## Shows one idle button per entry of `values`, in order, each `button_size` big. A
## button's text is `str(value)`, or the entry of `texts` at the same index when
## `texts` is given (to show a value differently, such as in uppercase); the `value`
## a tap reports is always the entry of `values`.
func set_choices(values: Array, button_size: Vector2, texts: Array = []) -> void:
	_set_button_count(values.size())
	var row := buttons()
	for i in values.size():
		var button := row[i]
		button.custom_minimum_size = button_size
		button.reset()
		button.value = values[i]
		if i < texts.size():
			button.text = str(texts[i])


## The buttons, in screen order.
func buttons() -> Array[ChoiceButton]:
	var row: Array[ChoiceButton] = []
	for child in get_children():
		if child is ChoiceButton and not child.is_queued_for_deletion():
			row.append(child)
	return row


## The button whose `value` matches `value` in type and value; null if none.
func button_for(value: Variant) -> ChoiceButton:
	for button in buttons():
		if typeof(button.value) == typeof(value) and button.value == value:
			return button
	return null


## Shakes and greys out the button with `value`. Await it to wait for the shake.
func show_wrong(value: Variant) -> void:
	var button := button_for(value)
	if button != null:
		await button.show_wrong()


## Turns the button with `value` green with a short hop. Await it to wait for the hop.
func show_correct(value: Variant) -> void:
	var button := button_for(value)
	if button != null:
		await button.show_correct()


func _set_button_count(count: int) -> void:
	var row := buttons()
	for i in range(count, row.size()):
		remove_child(row[i])
		row[i].queue_free()
	for i in range(row.size(), count):
		var button := CHOICE_SCENE.instantiate() as ChoiceButton
		button.chosen.connect(chosen.emit)
		add_child(button)
