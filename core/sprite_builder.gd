class_name SpriteBuilder
extends RefCounted
## Turns a sprite's text grid into an `Image` or an `ImageTexture`.
##
## A grid is `{"size": [w, h], "rows": ["..01..", ...]}`: one string per pixel row,
## one character per pixel, each a palette key or the transparent key (`.`). Textures
## use nearest filtering through the project default
## (`rendering/textures/canvas_textures/default_texture_filter`).
## `Content.validate()` checks the format; here a bad character becomes magenta and
## missing pixels stay transparent, so bad data never crashes.

const INVALID_COLOR := Color.MAGENTA


## The grid as an RGBA8 image of `size`, or null when the size is unusable.
static func build_image(grid: Dictionary, palette: Dictionary, transparent: String = ".") -> Image:
	var size := grid_size(grid)
	if size.x <= 0 or size.y <= 0:
		return null
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rows: Variant = grid.get("rows")
	if not rows is Array:
		return image
	for y in mini((rows as Array).size(), size.y):
		var row: Variant = rows[y]
		if not row is String:
			continue
		for x in mini(String(row).length(), size.x):
			var key := String(row)[x]
			if key == transparent:
				continue
			image.set_pixel(x, y, palette.get(key, INVALID_COLOR))
	return image


## The grid as a texture, or null when the size is unusable.
static func build_texture(grid: Dictionary, palette: Dictionary, transparent: String = ".") -> ImageTexture:
	var image := build_image(grid, palette, transparent)
	return ImageTexture.create_from_image(image) if image != null else null


## The grid's `size` as a Vector2i; (0, 0) when missing or invalid.
static func grid_size(grid: Dictionary) -> Vector2i:
	var size: Variant = grid.get("size")
	if not (size is Array and (size as Array).size() == 2):
		return Vector2i.ZERO
	if not ((size[0] is int or size[0] is float) and (size[1] is int or size[1] is float)):
		return Vector2i.ZERO
	return Vector2i(int(size[0]), int(size[1]))
