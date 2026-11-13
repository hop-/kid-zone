class_name MenuTiles
extends RefCounted
## Helpers the menu screens share: adding catalog tiles to a container, listing them,
## sizing them to fit an area, and filling a screen's icon + title row.

const TILE_SCENE := preload("res://ui/tile_button.tscn")


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
