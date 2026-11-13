extends Control
## A game's levels as tiles, each with 1–3 stars and a short label, in the level's
## `color` (easy green, medium orange, hard red in the catalog), or the mode's color
## when the level has none. Router only opens it for games whose catalog entry has
## `levels`.
##
## Params: `game_id`.

const TILE_SIZE := Vector2(88, 90)
const STAR_SPRITE := "icon_star_gold"

var _game_id := ""

@onready var _title_icon: TextureRect = %TitleIcon
@onready var _title: Label = %Title
@onready var _tiles: HBoxContainer = %Tiles


func setup_screen(params: Dictionary) -> void:
	_game_id = str(params.get("game_id", ""))


func _ready() -> void:
	var game_entry := Content.game(_game_id)
	if game_entry.is_empty():
		push_error("level_select: unknown game '%s'" % _game_id)
	MenuTiles.set_title(_title_icon, _title, str(game_entry.get("icon", "")),
			str(game_entry.get("title_key", "")))
	var mode_color := str(Content.mode(Content.mode_of(_game_id)).get("color", ""))
	for level_entry in Content.levels_for(_game_id):
		var level_color: Variant = level_entry.get("color")
		var color_name := mode_color
		if level_color is String and not String(level_color).is_empty():
			color_name = level_color
		var stars: PackedStringArray = []
		for i in clampi(int(level_entry.get("stars", 1)), 1, Content.MAX_LEVEL_STARS):
			stars.append(STAR_SPRITE)
		var tile := MenuTiles.add_tile(_tiles, str(level_entry.get("id", "")), stars,
				str(level_entry.get("title_key", "")), color_name, TILE_SIZE, 1)
		tile.pressed.connect(_on_level_pressed.bind(tile.item_id))


## The level tiles, in catalog order.
func tiles() -> Array[TileButton]:
	return MenuTiles.tiles_in(_tiles)


func _on_level_pressed(level_id: String) -> void:
	Router.go_to("game", {"game_id": _game_id, "level_id": level_id})
