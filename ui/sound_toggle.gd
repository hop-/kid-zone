class_name SoundToggle
extends IconButton
## Turns the sound effects on and off (`Settings.sfx_on`, which is saved) and shows
## `icon_sound_on` or `icon_sound_off` to match, also when the setting changes
## elsewhere.

const ICON_ON := "icon_sound_on"
const ICON_OFF := "icon_sound_off"


func _init() -> void:
	super()
	pressed.connect(_on_pressed)


func _ready() -> void:
	super()
	Settings.changed.connect(_refresh)
	_refresh()


func _on_pressed() -> void:
	Settings.sfx_on = not Settings.sfx_on


func _refresh() -> void:
	icon_id = ICON_ON if Settings.sfx_on else ICON_OFF
	_refresh_icon()
