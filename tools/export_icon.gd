extends SceneTree
## Writes `res://icon.svg` (the app icon) from the `app_icon` sprite grid in
## `content/sprites/icons.json` and the palette in `content/palette.json`.
##
## Run it with `make icon`, i.e.
## `godot --headless --path . --script res://tools/export_icon.gd`.
##
## Each horizontal run of same-colored pixels becomes one `<rect>` on the integer
## grid of a `viewBox` the size of the sprite, with `shape-rendering="crispEdges"`.
## Transparent pixels are left out. The SVG's pixel size is `SCALE` times the grid,
## so the icon sizes the exports render (multiples of 32 px) stay sharp.

const ICON_ID := "app_icon"
const OUTPUT := "res://icon.svg"
## Output pixels per grid pixel (32 x 8 = 256 px, like maze-runner's icon).
const SCALE := 8
const _Content := preload("res://autoload/content.gd")


func _init() -> void:
	var content: Node = _Content.new()
	content.load_content()
	var error := export_icon(content, OUTPUT)
	content.free()
	if error != OK:
		printerr("export_icon: cannot write %s (%s)" % [OUTPUT, error_string(error)])
	else:
		print("export_icon: wrote %s" % OUTPUT)
	quit(0 if error == OK else 1)


## Writes the SVG for `ICON_ID` from `content` to `path`.
static func export_icon(content: Node, path: String) -> Error:
	var svg := build_svg(content.sprite_grid(ICON_ID), content.palette_by_key(),
			content.transparent_key())
	if svg.is_empty():
		printerr("export_icon: no usable '%s' sprite grid" % ICON_ID)
		return ERR_INVALID_DATA
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(svg)
	file.close()
	return OK


## The SVG text for a sprite grid (`{"size": [w, h], "rows": [...]}`); "" when the
## grid is unusable. Characters that are not in `palette` are left transparent.
static func build_svg(grid: Dictionary, palette: Dictionary[String, Color],
		transparent: String) -> String:
	var size: Variant = grid.get("size")
	var rows: Variant = grid.get("rows")
	if not (size is Array and (size as Array).size() == 2 and rows is Array):
		return ""
	var width := int(size[0])
	var height := int(size[1])
	if width <= 0 or height <= 0:
		return ""
	var lines: PackedStringArray = [
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" shape-rendering="crispEdges">'
				% [width * SCALE, height * SCALE, width, height],
		"  <!-- Generated from the '%s' sprite grid by tools/export_icon.gd (make icon). Don't edit by hand. -->"
				% ICON_ID,
	]
	for y in mini(height, (rows as Array).size()):
		var row := str(rows[y])
		var x := 0
		while x < mini(width, row.length()):
			var key := row[x]
			var run := 1
			while x + run < mini(width, row.length()) and row[x + run] == key:
				run += 1
			if key != transparent and palette.has(key):
				lines.append('  <rect x="%d" y="%d" width="%d" height="1" fill="#%s"/>'
						% [x, y, run, palette[key].to_html(false)])
			x += run
	lines.append("</svg>")
	return "\n".join(lines) + "\n"
