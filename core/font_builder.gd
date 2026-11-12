class_name FontBuilder
extends RefCounted
## Builds a pixel `FontFile` from the glyph grids of `content/font.json`.
##
## The glyphs are packed into one atlas image (white ink, alpha = coverage, so the
## label's font color tints it) and registered as a bitmap font with
## `fixed_size = height` and integer-only scaling: at font size 9 a glyph pixel is one
## screen pixel, at 18 two, at 27 three.
##
## font.json: `{"height": 9, "baseline": 7, "spacing": 1, "glyphs": {...}}`. A glyph is
## a list of `height` rows of `#` (ink) and `.` (empty), or an object with optional
## `rows` and `advance`. A glyph's width is its widest inked column; its advance is that
## width plus `spacing`, unless `advance` is given. Rows below `baseline` are
## descenders. `Content.validate()` checks the format; this builder skips bad glyphs.

const INK := "#"
## Empty pixels between atlas cells, so nearest sampling never bleeds.
const ATLAS_PADDING := 1
const ATLAS_COLUMNS := 16


## Builds the font, or returns null when `data` has no usable height or glyphs.
static func build(data: Dictionary) -> FontFile:
	var height := _int(data.get("height"), 0)
	if height <= 0:
		return null
	var baseline := clampi(_int(data.get("baseline"), height), 1, height)
	var spacing := maxi(_int(data.get("spacing"), 1), 0)
	var glyphs: Variant = data.get("glyphs")
	if not glyphs is Dictionary or (glyphs as Dictionary).is_empty():
		return null

	# Parse each glyph into its rows (cropped to the inked width) and advance.
	var parsed: Array[Dictionary] = []
	var cell_width := 1
	for key: Variant in glyphs:
		if not (key is String and String(key).length() == 1):
			continue
		var glyph := _parse_glyph(glyphs[key], height, spacing)
		if glyph.is_empty():
			continue
		glyph["char"] = String(key).unicode_at(0)
		parsed.append(glyph)
		cell_width = maxi(cell_width, int(glyph["width"]))
	if parsed.is_empty():
		return null

	# Pack every glyph into a grid atlas.
	var cell := Vector2i(cell_width + ATLAS_PADDING, height + ATLAS_PADDING)
	var columns := mini(ATLAS_COLUMNS, parsed.size())
	var atlas_rows := ceili(float(parsed.size()) / columns)
	var atlas := Image.create_empty(columns * cell.x, atlas_rows * cell.y, false, Image.FORMAT_LA8)
	atlas.fill(Color(1, 1, 1, 0))

	var font := FontFile.new()
	font.fixed_size = height
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	font.multichannel_signed_distance_field = false
	font.allow_system_fallback = false
	font.font_name = "Kid Zone Pixel"

	var size := Vector2i(height, 0)
	font.set_cache_ascent(0, height, baseline)
	font.set_cache_descent(0, height, height - baseline)
	for i in parsed.size():
		var glyph := parsed[i]
		var origin := Vector2i((i % columns) * cell.x, (i / columns) * cell.y)
		var rows: PackedStringArray = glyph["rows"]
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == INK:
					atlas.set_pixel(origin.x + x, origin.y + y, Color(1, 1, 1, 1))
		var char_code: int = glyph["char"]
		var width: int = glyph["width"]
		font.set_glyph_advance(0, height, char_code, Vector2(glyph["advance"], 0))
		if width == 0:
			# Nothing to draw (space): advance only, no texture.
			font.set_glyph_texture_idx(0, size, char_code, -1)
			continue
		font.set_glyph_offset(0, size, char_code, Vector2(0, -baseline))
		font.set_glyph_size(0, size, char_code, Vector2(width, height))
		font.set_glyph_uv_rect(0, size, char_code, Rect2(origin, Vector2(width, height)))
		font.set_glyph_texture_idx(0, size, char_code, 0)
	font.set_texture_image(0, size, 0, atlas)
	return font


## {rows: PackedStringArray (cropped to width), width: int, advance: int}, or {} when
## the glyph is malformed.
static func _parse_glyph(entry: Variant, height: int, spacing: int) -> Dictionary:
	var rows_value: Variant = entry
	var advance := -1
	if entry is Dictionary:
		rows_value = entry.get("rows", [])
		if entry.has("advance"):
			advance = _int(entry["advance"], -1)
	if not rows_value is Array:
		return {}
	var rows: PackedStringArray = []
	var width := 0
	for row: Variant in rows_value:
		if not row is String:
			return {}
		rows.append(row)
		var last_ink := String(row).rfind(INK)
		width = maxi(width, last_ink + 1)
	if not rows.is_empty() and rows.size() != height:
		return {}
	if rows.is_empty():
		# An advance-only glyph such as space: nothing to draw.
		if advance < 0:
			return {}
		for y in height:
			rows.append("")
	for y in rows.size():
		rows[y] = rows[y].left(width)
	if advance < 0:
		advance = width + spacing
	return {"rows": rows, "width": width, "advance": advance}


## A JSON number as an int, or `fallback` for anything else.
static func _int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	return fallback
