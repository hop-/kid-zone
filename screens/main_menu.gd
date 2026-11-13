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
## Menu icons are 16x16 sprites.
const ICON_SIZE := 16.0
## A tile's room around its content: the bevel's content margins plus 1 px.
const TILE_PADDING := Vector2(8, 6)
## The gap between a tile's icons and its label (`tile_button.tscn`).
const TILE_CONTENT_GAP := 4.0

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


## Sizes the tiles to fit the space under the title, and narrows the flow container
## so it wraps after the chosen number of columns. The labels are 18 px when every
## one fits its tile, and the icons 2x when there's height for them.
func _layout_tiles() -> void:
	var mode_tiles := tiles()
	var area := Vector2(_layout.size.x,
			_layout.size.y - _title.get_combined_minimum_size().y - 3.0 * MIN_SPACING)
	if mode_tiles.is_empty() or area.x <= 0.0 or area.y <= 0.0:
		return
	var grid := MenuTiles.fit_grid(mode_tiles.size(), area, MAX_TILE_SIZE, TILE_GAP)
	var columns: int = grid["columns"]
	var tile_size: Vector2 = grid["size"]
	_tiles.custom_minimum_size.x = columns * tile_size.x + (columns - 1) * TILE_GAP.x
	# One label size and icon scale for every tile, so the tiles match.
	var room := tile_size - TILE_PADDING
	var label_size := Art.FONT_MEDIUM
	for tile in mode_tiles:
		if Art.font().get_string_size(tile.label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1,
				Art.FONT_MEDIUM).x > room.x:
			label_size = Art.FONT_SMALL
	var icon_scale := 2
	if ICON_SIZE * icon_scale + TILE_CONTENT_GAP + label_size > room.y:
		icon_scale = 1
	if ICON_SIZE * icon_scale + TILE_CONTENT_GAP + label_size > room.y:
		label_size = Art.FONT_SMALL
	for tile in mode_tiles:
		tile.custom_minimum_size = tile_size
		tile.icon_scale = icon_scale
		tile.label_variation = Art.LABEL_MEDIUM if label_size == Art.FONT_MEDIUM else &""


func _on_mode_pressed(mode_id: String) -> void:
	Router.go_to("mode_menu", {"mode_id": mode_id})
