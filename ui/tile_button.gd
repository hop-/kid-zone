class_name TileButton
extends KidButton
## A big menu tile: a row of icon sprites over a short translated label, on a beveled
## tile in a palette color. Main menu, mode menu, level select and round end use it.
##
## Set it up with `setup()` (or the properties) before or after it enters the tree.
## The content shifts down 1 px while pressed, like the bevel.

## Sprite ids shown in a row, e.g. `["icon_math"]` or three `icon_star_gold`.
@export var icon_ids: PackedStringArray = []:
	set(value):
		icon_ids = value
		_refresh()
## Each icon is drawn at this integer scale.
@export var icon_scale: int = 2:
	set(value):
		icon_scale = maxi(1, value)
		_refresh()
## A translation key from ui.csv or the catalog; shown through `tr()`.
@export var label_key: String = "":
	set(value):
		label_key = value
		_refresh()
## A palette color name for the tile; "" keeps the theme's default button.
@export var color_name: String = "":
	set(value):
		color_name = value
		_refresh()
## The label's theme type variation (`LabelMedium` = 18 px, "" = 9 px).
@export var label_variation: StringName = &"LabelMedium":
	set(value):
		label_variation = value
		_refresh()

## The value the screen attached to this tile (a mode, game or level id).
var item_id: String = ""

@onready var _content: VBoxContainer = $Content
@onready var _icons: HBoxContainer = $Content/Icons
@onready var _label: Label = $Content/Label


## Configures the whole tile at once.
func setup(id: String, icons: PackedStringArray, key: String, color: String,
		min_size: Vector2, icons_scale: int = 2) -> void:
	item_id = id
	custom_minimum_size = min_size
	icon_ids = icons
	icon_scale = icons_scale
	label_key = key
	color_name = color


## The label's shown (translated) text.
func label_text() -> String:
	return _label.text if is_node_ready() else tr(label_key)


func _ready() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and is_node_ready():
		# Follow the bevel: content sits 1 px lower while the tile is held down.
		var shift := 1.0 if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 0.0
		_content.position = Vector2(shift, shift)


func _refresh() -> void:
	if not is_node_ready():
		return
	for child in _icons.get_children():
		_icons.remove_child(child)
		child.queue_free()
	for sprite_id in icon_ids:
		var texture := Art.sprite(sprite_id)
		var rect := TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = texture.get_size() * icon_scale
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icons.add_child(rect)
	_label.text = tr(label_key) if not label_key.is_empty() else ""
	_label.visible = not label_key.is_empty()
	_label.theme_type_variation = label_variation
	_apply_color()


func _apply_color() -> void:
	for style_name in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		remove_theme_stylebox_override(style_name)
	if color_name.is_empty():
		# The theme's white button: dark text, no shadow.
		_label.add_theme_color_override(&"font_color", Art.theme_color("text_dark"))
		_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
		return
	var fill := Content.color(color_name)
	var normal := Art.bevel_style(fill)
	var pressed_style := Art.bevel_style(fill, true)
	add_theme_stylebox_override(&"normal", normal)
	add_theme_stylebox_override(&"hover", normal)
	add_theme_stylebox_override(&"pressed", pressed_style)
	add_theme_stylebox_override(&"hover_pressed", pressed_style)
	add_theme_stylebox_override(&"disabled", Art.bevel_style(Art.theme_color("button_disabled")))
	# Light text with a 1 px dark drop shadow reads on every tile color.
	_label.add_theme_color_override(&"font_color", Art.theme_color("text"))
	_label.add_theme_color_override(&"font_shadow_color", Art.theme_color("outline"))
