extends Node
## Every visual asset, built from the content data: sprite textures, the pixel font and
## the UI theme.
##
## - `sprite(id)` returns `<override_root>/<id>.png` when that resource exists (drop a
##   PNG into `res://assets/sprites/` to replace a sprite), else the texture built
##   from the sprite's grid in `content/sprites/*.json`. Results are cached.
## - `font()` is the bitmap `FontFile` built from `content/font.json`: fixed size 9,
##   integer-only scaling, so use font sizes 9, 18 and 27 (`FONT_SIZES`).
## - `theme()` is the UI `Theme`. On startup it is set on the root window, together
##   with the clear color, so every Control uses the pixel font and palette colors.
##
## Registered as the `Art` autoload after `Content`, whose data it reads. Tests can
## make their own instance (`preload("res://autoload/art.gd").new()`, free it
## afterwards), point `override_root` at a fixture folder, or set `content` to another
## `Content` instance.

const _SpriteBuilder := preload("res://core/sprite_builder.gd")
const _FontBuilder := preload("res://core/font_builder.gd")

const DEFAULT_OVERRIDE_ROOT := "res://assets/sprites"
## The font's pixel height (font.json `height`); the theme's base font size.
const FONT_SMALL := 9
const FONT_MEDIUM := 18
const FONT_LARGE := 27
const FONT_SIZES: Array[int] = [FONT_SMALL, FONT_MEDIUM, FONT_LARGE]

## Theme roles -> palette color names. The UI asks for roles (`theme_color()`), so a
## recolor is an edit here. Tile colors come from each mode's catalog `color`.
const THEME_COLORS: Dictionary[String, String] = {
	"background": "navy",
	"text": "white",
	"text_dark": "black",
	"text_disabled": "silver",
	"button": "white",
	"button_hover": "sky",
	"button_pressed": "silver",
	"button_disabled": "dark_grey",
	"outline": "black",
	"bevel_light": "white",
	"bevel_dark": "dark_grey",
	"highlight": "yellow",
	"gold": "yellow",
	"silver": "silver",
}

## Theme type variations: Label and Button at the medium and large font sizes.
const LABEL_MEDIUM := &"LabelMedium"
const LABEL_LARGE := &"LabelLarge"
const BUTTON_MEDIUM := &"ButtonMedium"
const BUTTON_LARGE := &"ButtonLarge"

## Bevel geometry, in virtual pixels: a 1 px outline, a 1 px light edge on the top
## and left, and a 2 px dark edge on the bottom and right.
const _OUTLINE := 1
const _LIGHT := 1
const _DARK := 2
const _BEVEL_IMAGE_SIZE := 8

## Where override PNGs are looked up.
var override_root: String = DEFAULT_OVERRIDE_ROOT:
	set(value):
		override_root = value.trim_suffix("/")
		_textures.clear()
## The Content node to read grids, palette and font from; null means the `Content`
## autoload.
var content: Node = null:
	set(value):
		content = value
		clear_cache()

var _textures: Dictionary[String, Texture2D] = {}
var _font: FontFile = null
var _theme: Theme = null
var _missing_texture: Texture2D = null


func _ready() -> void:
	apply_to_window(get_tree().root)


## Sets the theme on `window` and the clear color to the theme background.
func apply_to_window(window: Window) -> void:
	window.theme = theme()
	RenderingServer.set_default_clear_color(theme_color("background"))


## Drops every built texture, the font and the theme, so they are rebuilt from the
## current content on next use.
func clear_cache() -> void:
	_textures.clear()
	_font = null
	_theme = null


# --- sprites ---------------------------------------------------------------------

## The sprite's texture: the override PNG if there is one, else its grid built with
## the palette. An unknown id gives a small magenta placeholder and an error.
func sprite(sprite_id: String) -> Texture2D:
	if _textures.has(sprite_id):
		return _textures[sprite_id]
	var texture := _override_texture(sprite_id)
	if texture == null:
		var data: Variant = _content()
		if data != null and data.has_sprite_grid(sprite_id):
			texture = _SpriteBuilder.build_texture(data.sprite_grid(sprite_id),
					data.palette_by_key(), data.transparent_key())
	if texture == null:
		push_error("Art: no sprite '%s'" % sprite_id)
		return _placeholder()
	_textures[sprite_id] = texture
	return texture


## True when `sprite(id)` would find an override PNG or a grid.
func has_sprite(sprite_id: String) -> bool:
	if _textures.has(sprite_id) or ResourceLoader.exists(_override_path(sprite_id)):
		return true
	var data: Variant = _content()
	return data != null and data.has_sprite_grid(sprite_id)


## True when the sprite comes from an override PNG.
func is_overridden(sprite_id: String) -> bool:
	return ResourceLoader.exists(_override_path(sprite_id))


func _override_path(sprite_id: String) -> String:
	return override_root.path_join(sprite_id + ".png")


func _override_texture(sprite_id: String) -> Texture2D:
	var path := _override_path(sprite_id)
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Art: %s is not a texture" % path)
	return texture


func _placeholder() -> Texture2D:
	if _missing_texture == null:
		var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(_SpriteBuilder.INVALID_COLOR)
		_missing_texture = ImageTexture.create_from_image(image)
	return _missing_texture


# --- font and theme --------------------------------------------------------------

## The pixel font from font.json, or the engine fallback font (with an error) if it
## can't be built.
func font() -> Font:
	if _font == null:
		var data: Variant = _content()
		_font = _FontBuilder.build(data.font_data()) if data != null else null
		if _font == null:
			push_error("Art: cannot build the pixel font from font.json")
			return ThemeDB.fallback_font
	return _font


## The palette color for a theme role (see `THEME_COLORS`), or a palette color name.
func theme_color(role: String) -> Color:
	var color_name: String = THEME_COLORS.get(role, role)
	var data: Variant = _content()
	if data == null:
		return Color.MAGENTA
	return data.color(color_name)


## A pixel-bevel button style with `fill` inside: a dark outline, a light top-left
## edge and a dark bottom-right edge. `pressed` swaps the edges, so the button looks
## pushed in. Use it for tiles with their own color.
func bevel_style(fill: Color, pressed: bool = false) -> StyleBoxTexture:
	var light := theme_color("bevel_light")
	var dark := theme_color("bevel_dark")
	if pressed:
		var swap := light
		light = dark
		dark = swap
	var size := _BEVEL_IMAGE_SIZE
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	var top_left := _LIGHT if not pressed else _DARK
	var bottom_right := _DARK if not pressed else _LIGHT
	var inner := Rect2i(_OUTLINE, _OUTLINE, size - 2 * _OUTLINE, size - 2 * _OUTLINE)
	# Light edge on the top and left, dark edge on the bottom and right.
	image.fill_rect(Rect2i(inner.position, Vector2i(inner.size.x, top_left)), light)
	image.fill_rect(Rect2i(inner.position, Vector2i(top_left, inner.size.y)), light)
	image.fill_rect(Rect2i(inner.position.x, inner.end.y - bottom_right, inner.size.x, bottom_right), dark)
	image.fill_rect(Rect2i(inner.end.x - bottom_right, inner.position.y, bottom_right, inner.size.y), dark)
	# Outline with transparent corners for a rounded pixel look.
	var outline := theme_color("outline")
	image.fill_rect(Rect2i(1, 0, size - 2, 1), outline)
	image.fill_rect(Rect2i(1, size - 1, size - 2, 1), outline)
	image.fill_rect(Rect2i(0, 1, 1, size - 2), outline)
	image.fill_rect(Rect2i(size - 1, 1, 1, size - 2), outline)
	for corner in [Vector2i(0, 0), Vector2i(size - 1, 0), Vector2i(0, size - 1), Vector2i(size - 1, size - 1)]:
		image.set_pixelv(corner, Color(0, 0, 0, 0))

	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	var margin_top := _OUTLINE + top_left
	var margin_bottom := _OUTLINE + bottom_right
	style.texture_margin_left = margin_top
	style.texture_margin_top = margin_top
	style.texture_margin_right = margin_bottom
	style.texture_margin_bottom = margin_bottom
	# Content sits 1 px lower and to the right when pressed.
	var shift := 1 if pressed else 0
	style.content_margin_left = margin_top + 1 + shift
	style.content_margin_top = margin_top + shift
	style.content_margin_right = margin_bottom + 1 - shift
	style.content_margin_bottom = margin_bottom - shift
	return style


## The UI theme, built on first use: pixel font at 9 px, palette colors for text and
## background, and bevel styles for buttons. Type variations `LabelMedium`,
## `LabelLarge`, `ButtonMedium` and `ButtonLarge` use 18 and 27 px.
func theme() -> Theme:
	if _theme != null:
		return _theme
	var built := Theme.new()
	built.default_font = font()
	built.default_font_size = FONT_SMALL

	var text := theme_color("text")
	var text_dark := theme_color("text_dark")
	var text_disabled := theme_color("text_disabled")

	built.set_color(&"font_color", &"Label", text)

	var normal := bevel_style(theme_color("button"))
	var hover := bevel_style(theme_color("button_hover"))
	var pressed := bevel_style(theme_color("button_pressed"), true)
	var disabled := bevel_style(theme_color("button_disabled"))
	built.set_stylebox(&"normal", &"Button", normal)
	built.set_stylebox(&"hover", &"Button", hover)
	built.set_stylebox(&"pressed", &"Button", pressed)
	built.set_stylebox(&"hover_pressed", &"Button", pressed)
	built.set_stylebox(&"disabled", &"Button", disabled)
	built.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		built.set_color(color_name, &"Button", text_dark)
	built.set_color(&"font_disabled_color", &"Button", text_disabled)
	built.set_color(&"icon_normal_color", &"Button", Color.WHITE)
	built.set_color(&"icon_disabled_color", &"Button", Color(1, 1, 1, 0.5))

	var panel := StyleBoxFlat.new()
	panel.bg_color = theme_color("background")
	built.set_stylebox(&"panel", &"Panel", panel)
	built.set_stylebox(&"panel", &"PanelContainer", panel)

	_add_variation(built, LABEL_MEDIUM, &"Label", FONT_MEDIUM)
	_add_variation(built, LABEL_LARGE, &"Label", FONT_LARGE)
	_add_variation(built, BUTTON_MEDIUM, &"Button", FONT_MEDIUM)
	_add_variation(built, BUTTON_LARGE, &"Button", FONT_LARGE)
	_theme = built
	return _theme


static func _add_variation(target: Theme, variation: StringName, base: StringName, size: int) -> void:
	target.set_type_variation(variation, base)
	target.set_font_size(&"font_size", variation, size)


func _content() -> Node:
	if content != null:
		return content
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Content")
