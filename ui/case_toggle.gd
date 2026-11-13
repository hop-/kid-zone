class_name CaseToggle
extends IconButton
## Switches the word game between UPPERCASE and lowercase (`Settings.letter_case`,
## which is saved) and shows `icon_case_upper` ("AB") or `icon_case_lower` ("ab") to
## match, also when the setting changes elsewhere. Menu and button labels keep their
## case.

const ICON_UPPER := "icon_case_upper"
const ICON_LOWER := "icon_case_lower"


func _init() -> void:
	super()
	pressed.connect(_on_pressed)


func _ready() -> void:
	super()
	Settings.changed.connect(_refresh)
	_refresh()


func _on_pressed() -> void:
	Settings.letter_case = Settings.LETTER_CASE_LOWER \
			if Settings.letter_case == Settings.LETTER_CASE_UPPER else Settings.LETTER_CASE_UPPER


func _refresh() -> void:
	icon_id = ICON_UPPER if Settings.letter_case == Settings.LETTER_CASE_UPPER else ICON_LOWER
	_refresh_icon()
