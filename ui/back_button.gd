class_name BackButton
extends IconButton
## The top-left back button of every screen but the main menu. It calls
## `Router.back()` on release, which plays the `back` sound, so it plays no `tap`.


func _init() -> void:
	super()
	icon_id = "icon_back"
	press_sfx = ""
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	Router.back()
