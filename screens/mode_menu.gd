extends Control
## One mode's games as tiles, from the catalog, under the mode's title. A game with
## `levels` opens level select; one without opens the game directly.
##
## The tiles fit any number of games, as on the main menu: they are `MAX_TILE_SIZE`
## while the games fit in one row at that size (three do), and otherwise shrink and
## wrap into rows to fill the space between the title row and the bottom. The tiles
## always start below the back button (`BackButton.CLEAR_BOTTOM`). The layout
## follows the view size, which grows taller on 4:3 and 16:10 screens.
##
## Params: `mode_id`.

## The biggest tile.
const MAX_TILE_SIZE := Vector2(96, 96)
## Space between tiles: x between columns, y between rows (the `Tiles` separations).
const TILE_GAP := Vector2(8, 8)
## The least space kept between the title row and the tiles, and below the tiles.
const MIN_SPACING := 4.0

var _mode_id := ""

@onready var _layout: VBoxContainer = $Layout
@onready var _title_row: HBoxContainer = $Layout/TitleRow
@onready var _top_space: Control = $Layout/TopSpace
@onready var _bottom_space: Control = $Layout/BottomSpace
@onready var _title_icon: TextureRect = %TitleIcon
@onready var _title: Label = %Title
@onready var _tiles: HFlowContainer = %Tiles


func setup_screen(params: Dictionary) -> void:
	_mode_id = str(params.get("mode_id", ""))


func _ready() -> void:
	var mode_entry := Content.mode(_mode_id)
	if mode_entry.is_empty():
		push_error("mode_menu: unknown mode '%s'" % _mode_id)
	MenuTiles.set_title(_title_icon, _title, str(mode_entry.get("icon", "")),
			str(mode_entry.get("title_key", "")))
	var color_name := str(mode_entry.get("color", ""))
	for game_entry in Content.games_for(_mode_id):
		var tile := MenuTiles.add_tile(_tiles, str(game_entry.get("id", "")),
				[str(game_entry.get("icon", ""))], str(game_entry.get("title_key", "")),
				color_name, MAX_TILE_SIZE)
		tile.pressed.connect(_on_game_pressed.bind(tile.item_id))
	# The spacers keep the tiles below the back button and its touch area, and
	# `MIN_SPACING` clear of the title row and the bottom edge.
	_top_space.custom_minimum_size.y = maxf(MIN_SPACING, BackButton.CLEAR_BOTTOM
			- _layout.offset_top - _title_row.get_combined_minimum_size().y)
	_bottom_space.custom_minimum_size.y = MIN_SPACING
	_layout.resized.connect(_layout_tiles)
	_layout_tiles()


## The game tiles, in catalog order.
func tiles() -> Array[TileButton]:
	return MenuTiles.tiles_in(_tiles)


## Sizes the tiles to fit the space under the title row (`MenuTiles.fit_tiles()`).
func _layout_tiles() -> void:
	var area := Vector2(_layout.size.x, _layout.size.y
			- _title_row.get_combined_minimum_size().y
			- _top_space.custom_minimum_size.y - _bottom_space.custom_minimum_size.y)
	MenuTiles.fit_tiles(_tiles, area, MAX_TILE_SIZE, TILE_GAP)


func _on_game_pressed(game_id: String) -> void:
	if Content.levels_for(game_id).is_empty():
		Router.go_to("game", {"game_id": game_id, "level_id": ""})
	else:
		Router.go_to("level_select", {"game_id": game_id})
