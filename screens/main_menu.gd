extends Control
## The first screen: the "Kid Zone" title, one big tile per catalog mode, and the
## letter-case and sound toggles at the top right. Back does nothing here (see Router).
##
## The tiles fit any number of modes: they are `MAX_TILE_SIZE` while the modes fit
## in one row at that size (two do), and otherwise shrink and wrap into rows to fill
## the space under the title. Small tiles use 1x icons and the 9 px label. The layout
## follows the view size, which grows taller on 4:3 and 16:10 screens.

## The biggest tile.
const MAX_TILE_SIZE := Vector2(120, 110)
## Space between tiles: x between columns, y between rows (the `Tiles` separations).
const TILE_GAP := Vector2(16, 8)
## The least space kept above the title, between it and the tiles, and below them.
const MIN_SPACING := 4.0

@onready var _layout: VBoxContainer = $Layout
@onready var _title: Label = %Title
@onready var _tiles: HFlowContainer = %Tiles


func _ready() -> void:
	_title.text = tr("APP_TITLE")
	for mode_entry in Content.modes():
		var tile := MenuTiles.add_tile(_tiles, str(mode_entry.get("id", "")),
				[str(mode_entry.get("icon", ""))], str(mode_entry.get("title_key", "")),
				str(mode_entry.get("color", "")), MAX_TILE_SIZE)
		tile.pressed.connect(_on_mode_pressed.bind(tile.item_id))
	_layout.resized.connect(_layout_tiles)
	_layout_tiles()


## The mode tiles, in catalog order.
func tiles() -> Array[TileButton]:
	return MenuTiles.tiles_in(_tiles)


## Sizes the tiles to fit the space under the title (`MenuTiles.fit_tiles()`).
func _layout_tiles() -> void:
	var area := Vector2(_layout.size.x,
			_layout.size.y - _title.get_combined_minimum_size().y - 3.0 * MIN_SPACING)
	MenuTiles.fit_tiles(_tiles, area, MAX_TILE_SIZE, TILE_GAP)


func _on_mode_pressed(mode_id: String) -> void:
	Router.go_to("mode_menu", {"mode_id": mode_id})
