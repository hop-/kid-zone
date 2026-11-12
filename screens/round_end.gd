extends Control
## The end of a round: the stars earned, shown one by one and followed by the
## `fanfare`, and "again" (the same game and level) and "home" tiles.
##
## Params: `game_id`, `level_id` ("" for a game without levels), and `stars` (one
## `RoundController.Star` per question).

const TILE_SIZE := Vector2(80, 64)
const AGAIN_COLOR := "green"
const HOME_COLOR := "orange"
const FANFARE_SFX := "fanfare"

var _game_id := ""
var _level_id := ""
var _stars: Array = []

@onready var _star_bar: StarBar = %Stars
@onready var _buttons: HBoxContainer = %Buttons


func setup_screen(params: Dictionary) -> void:
	_game_id = str(params.get("game_id", ""))
	_level_id = str(params.get("level_id", ""))
	var stars: Variant = params.get("stars", [])
	_stars = stars if stars is Array else []


func _ready() -> void:
	_star_bar.slot_count = maxi(_stars.size(), Content.round_length(_game_id))
	var again := MenuTiles.add_tile(_buttons, "again", ["icon_again"], "ROUND_AGAIN",
			AGAIN_COLOR, TILE_SIZE)
	again.pressed.connect(_on_again_pressed)
	var home := MenuTiles.add_tile(_buttons, "home", ["icon_home"], "ROUND_HOME",
			HOME_COLOR, TILE_SIZE)
	home.pressed.connect(_on_home_pressed)
	_celebrate()


## The "again" and "home" tiles.
func tiles() -> Array[TileButton]:
	return MenuTiles.tiles_in(_buttons)


func star_bar() -> StarBar:
	return _star_bar


func _celebrate() -> void:
	await _star_bar.reveal(_stars)
	Audio.play_sfx(FANFARE_SFX)


func _on_again_pressed() -> void:
	# Round end took the game's place on the stack, so "again" takes its place back.
	Router.go_to("game", {"game_id": _game_id, "level_id": _level_id}, true)


func _on_home_pressed() -> void:
	Router.home()
