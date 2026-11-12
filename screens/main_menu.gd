extends Control
## The first screen: the "Kid Zone" title, one big tile per catalog mode, and the
## sound toggle at the top right. Back does nothing here (see Router).

const TILE_SIZE := Vector2(120, 110)

@onready var _title: Label = %Title
@onready var _tiles: HBoxContainer = %Tiles


func _ready() -> void:
	_title.text = tr("APP_TITLE")
	for mode_entry in Content.modes():
		var tile := MenuTiles.add_tile(_tiles, str(mode_entry.get("id", "")),
				[str(mode_entry.get("icon", ""))], str(mode_entry.get("title_key", "")),
				str(mode_entry.get("color", "")), TILE_SIZE)
		tile.pressed.connect(_on_mode_pressed.bind(tile.item_id))


## The mode tiles, in catalog order.
func tiles() -> Array[TileButton]:
	return MenuTiles.tiles_in(_tiles)


func _on_mode_pressed(mode_id: String) -> void:
	Router.go_to("mode_menu", {"mode_id": mode_id})
