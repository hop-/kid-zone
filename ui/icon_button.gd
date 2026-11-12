class_name IconButton
extends KidButton
## A small square button showing one 16×16 icon sprite (`icon_id`) on the default
## bevel. It's drawn at 24×24 and touches at 32×32 (`touch_margin` 4). The back
## button and the sound toggle extend it.

const BUTTON_SIZE := Vector2(24, 24)
const TOUCH_MARGIN := 4

## The sprite id shown on the button.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		if is_node_ready():
			_refresh_icon()


func _init() -> void:
	super()
	touch_margin = TOUCH_MARGIN
	custom_minimum_size = BUTTON_SIZE
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	expand_icon = false


func _ready() -> void:
	_refresh_icon()


func _refresh_icon() -> void:
	icon = Art.sprite(icon_id) if not icon_id.is_empty() else null
