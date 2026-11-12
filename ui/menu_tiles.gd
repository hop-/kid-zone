class_name MenuTiles
extends RefCounted
## Helpers the menu screens share: adding catalog tiles to a container, listing them,
## and filling a screen's icon + title row.

const TILE_SCENE := preload("res://ui/tile_button.tscn")


## Adds a `TileButton` for one catalog item to `container` and returns it.
static func add_tile(container: Container, item_id: String, icon_ids: PackedStringArray,
		label_key: String, color_name: String, min_size: Vector2, icon_scale: int = 2) -> TileButton:
	var tile := TILE_SCENE.instantiate() as TileButton
	container.add_child(tile)
	tile.setup(item_id, icon_ids, label_key, color_name, min_size, icon_scale)
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
