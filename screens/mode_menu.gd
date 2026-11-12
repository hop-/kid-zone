extends Control
## One mode's games as tiles, from the catalog, under the mode's title. A game with
## `levels` opens level select; one without opens the game directly.
##
## Params: `mode_id`.

const TILE_SIZE := Vector2(96, 96)

var _mode_id := ""

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
				color_name, TILE_SIZE)
		tile.pressed.connect(_on_game_pressed.bind(tile.item_id))


## The game tiles, in catalog order.
func tiles() -> Array[TileButton]:
	return MenuTiles.tiles_in(_tiles)


func _on_game_pressed(game_id: String) -> void:
	if Content.levels_for(game_id).is_empty():
		Router.go_to("game", {"game_id": game_id, "level_id": ""})
	else:
		Router.go_to("level_select", {"game_id": game_id})
