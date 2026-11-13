class_name MenuTiles
extends RefCounted
## Helpers the menu screens share: adding catalog tiles to a container, listing them,
## sizing them to fit an area, and filling a screen's icon + title row.

const TILE_SCENE := preload("res://ui/tile_button.tscn")
## Menu icons are 16x16 sprites.
const ICON_SIZE := 16.0
## A tile's room around its content: the bevel's content margins plus 1 px.
const TILE_PADDING := Vector2(8, 6)
## The gap between a tile's icons and its label (`tile_button.tscn`).
const TILE_CONTENT_GAP := 4.0


## Adds a `TileButton` for one catalog item to `container` and returns it.
static func add_tile(container: Container, item_id: String, icon_ids: PackedStringArray,
		label_key: String, color_name: String, min_size: Vector2, icon_scale: int = 2) -> TileButton:
	var tile := TILE_SCENE.instantiate() as TileButton
	# Set up before entering the tree, so the tile is built once, in its `_ready`.
	tile.setup(item_id, icon_ids, label_key, color_name, min_size, icon_scale)
	container.add_child(tile)
	return tile


## The `TileButton`s in `container`, in order.
static func tiles_in(container: Container) -> Array[TileButton]:
	var tiles: Array[TileButton] = []
	for child in container.get_children():
		if child is TileButton and not child.is_queued_for_deletion():
			tiles.append(child)
	return tiles


## Shows a screen title: the icon sprite (hidden when "") and the translated key.
static func set_title(icon_rect: TextureRect, label: Label, icon_id: String, title_key: String) -> void:
	icon_rect.visible = not icon_id.is_empty()
	if icon_rect.visible:
		icon_rect.texture = Art.sprite(icon_id)
	label.text = label.tr(title_key) if not title_key.is_empty() else ""


## The tile grid that fits `count` tiles into `area` with the biggest tiles: returns
## `{"columns": int, "size": Vector2}`. Tiles are at most `max_size`, `gap` apart
## (x between columns, y between rows). The tiles' smaller side decides; on a tie the
## layout with more columns (fewer rows) wins.
static func fit_grid(count: int, area: Vector2, max_size: Vector2, gap: Vector2) -> Dictionary:
	var best_columns := maxi(count, 1)
	var best_size := Vector2.ZERO
	for columns in range(maxi(count, 1), 0, -1):
		var rows := ceili(float(count) / columns)
		var size := Vector2(
				minf(max_size.x, floorf((area.x - gap.x * (columns - 1)) / columns)),
				minf(max_size.y, floorf((area.y - gap.y * (rows - 1)) / rows)))
		if minf(size.x, size.y) > minf(best_size.x, best_size.y):
			best_columns = columns
			best_size = size
	return {"columns": best_columns, "size": best_size}


## Sizes the tiles in `flow` to fit `area` with `fit_grid()`, and narrows `flow` so it
## wraps after the chosen number of columns. `flow` is a shrink-centered
## `HFlowContainer` whose separations are `gap`. Every tile gets the same label size
## and icon scale, so they match: 18 px labels when every label fits its tile (else
## 9 px), and 2x icons when there's height for them (else 1x). Does nothing for an
## empty `flow` or area.
static func fit_tiles(flow: HFlowContainer, area: Vector2, max_size: Vector2, gap: Vector2) -> void:
	var tiles := tiles_in(flow)
	if tiles.is_empty() or area.x <= 0.0 or area.y <= 0.0:
		return
	var grid := fit_grid(tiles.size(), area, max_size, gap)
	var columns: int = grid["columns"]
	var tile_size: Vector2 = grid["size"]
	flow.custom_minimum_size.x = columns * tile_size.x + (columns - 1) * gap.x
	var room := tile_size - TILE_PADDING
	var label_size := Art.FONT_MEDIUM
	for tile in tiles:
		if Art.font().get_string_size(tile.label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1,
				Art.FONT_MEDIUM).x > room.x:
			label_size = Art.FONT_SMALL
	var icon_scale := 2
	if ICON_SIZE * icon_scale + TILE_CONTENT_GAP + label_size > room.y:
		icon_scale = 1
	if ICON_SIZE * icon_scale + TILE_CONTENT_GAP + label_size > room.y:
		label_size = Art.FONT_SMALL
	for tile in tiles:
		tile.custom_minimum_size = tile_size
		tile.icon_scale = icon_scale
		tile.label_variation = Art.LABEL_MEDIUM if label_size == Art.FONT_MEDIUM else &""
