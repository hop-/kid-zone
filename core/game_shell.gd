class_name GameShell
extends Control
## The `game` screen: it runs one round of any `MiniGame`.
##
## It looks the game up in the catalog, instances the game's scene into its
## `GameSlot`, calls `setup()` with the merged game + level params and a seeded RNG,
## and then loops: `next_question()` -> `present()` -> wait for `choice_made` ->
## `RoundController.submit()`.
## - Wrong: the `wrong` sound and `show_wrong(value)`; the kid tries again.
## - Correct: the `correct` sound, a gold (first try) or silver star in the top bar,
##   `show_correct()`, and about `NEXT_DELAY` seconds after the tap the next question.
## - After `round_length` questions it opens round end in its place on the stack.
## Input to the game is blocked from every tap until its feedback has finished (and,
## after a correct tap, until the next question shows). The back button stays live.
##
## Params (Router): `game_id`, `level_id` ("" for a game without levels), and an
## optional `seed` (an int) that replays the same questions; without it the RNG is
## seeded from `randi()`.

const WRONG_SFX := "wrong"
const CORRECT_SFX := "correct"
const ROUND_END_SCREEN := "round_end"
## Seconds from a correct tap to the next question (or to round end).
const NEXT_DELAY := 0.8

var _game_id := ""
var _level_id := ""
var _seed: int = randi()
var _rng := RandomNumberGenerator.new()
var _controller := RoundController.new()
var _game: MiniGame = null
var _question: Dictionary = {}
var _locked := true

@onready var _slot: Control = %GameSlot
@onready var _blocker: Control = %InputBlocker
@onready var _star_bar: StarBar = %StarBar


func setup_screen(params: Dictionary) -> void:
	_game_id = str(params.get("game_id", ""))
	_level_id = str(params.get("level_id", ""))
	var seed_value: Variant = params.get("seed")
	if seed_value is int or seed_value is float:
		_seed = int(seed_value)
	else:
		if seed_value != null:
			push_warning("GameShell: ignoring non-numeric seed %s" % [seed_value])
		_seed = randi()


func _ready() -> void:
	_set_locked(true)
	_rng.seed = _seed
	var round_length := Content.round_length(_game_id)
	_star_bar.slot_count = round_length
	_star_bar.clear()
	_game = _instance_game()
	if _game == null:
		return
	_slot.add_child(_game)
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game.choice_made.connect(_on_choice_made)
	_game.setup(Content.merged_params(_game_id, _level_id), _rng)
	_controller.start(round_length)
	_next_question()


# --- accessors (tests and debug tools) -------------------------------------------

## The running game; null when its scene could not be loaded.
func game() -> MiniGame:
	return _game


func controller() -> RoundController:
	return _controller


func star_bar() -> StarBar:
	return _star_bar


## The question on screen (a copy).
func current_question() -> Dictionary:
	return _question.duplicate(true)


func is_input_locked() -> bool:
	return _locked


## The seed of this round's RNG.
func get_seed() -> int:
	return _seed


func game_id() -> String:
	return _game_id


func level_id() -> String:
	return _level_id


# --- the round loop --------------------------------------------------------------

func _instance_game() -> MiniGame:
	var entry := Content.game(_game_id)
	if entry.is_empty():
		push_error("GameShell: unknown game '%s'" % _game_id)
		return null
	var path := str(entry.get("scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("GameShell: game '%s' has no scene at '%s'" % [_game_id, path])
		return null
	var scene := load(path) as PackedScene
	var node: Node = scene.instantiate() if scene != null else null
	if not node is MiniGame:
		push_error("GameShell: the root of %s does not extend MiniGame" % path)
		if node != null:
			node.free()
		return null
	return node as MiniGame


func _next_question() -> void:
	if _controller.is_done():
		_finish_round()
		return
	var question := _game.next_question()
	if not question.has("answer") or not question.has("choices"):
		push_error("GameShell: %s.next_question() returned no answer or choices: %s"
				% [_game_id, question])
		return
	_question = question
	_game.present(question)
	_set_locked(false)


func _on_choice_made(value: Variant) -> void:
	if _locked or _controller.is_done() or _question.is_empty():
		return
	_set_locked(true)
	var correct := _matches(value, _question["answer"])
	var index := _controller.question_index()
	_controller.submit(correct)
	if not correct:
		Audio.play_sfx(WRONG_SFX)
		await _feedback(_game.show_wrong.bind(value))
		_set_locked(false)
		return
	Audio.play_sfx(CORRECT_SFX)
	_star_bar.set_star(index, _controller.stars()[index])
	# The pause runs alongside the animation, so the next question comes about
	# NEXT_DELAY after the tap however long the game's feedback is.
	var pause := create_tween()
	pause.tween_interval(NEXT_DELAY)
	await _feedback(_game.show_correct)
	if pause.is_running():
		await pause.finished
	_question = {}
	_next_question()


## Calls a feedback method and returns when the game emits `feedback_done`, even if
## the game emits it before the method returns.
func _feedback(method: Callable) -> void:
	var state := {"done": false}
	_game.feedback_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	method.call()
	if not state["done"]:
		await _game.feedback_done


func _finish_round() -> void:
	_set_locked(true)
	var stars: Array[int] = []
	for star in _controller.stars():
		stars.append(int(star))
	Router.go_to(ROUND_END_SCREEN,
			{"game_id": _game_id, "level_id": _level_id, "stars": stars}, true)


func _set_locked(locked: bool) -> void:
	_locked = locked
	if _blocker != null:
		_blocker.visible = locked


## Numbers compare by value (JSON numbers may be floats); anything else must match
## in type and value.
static func _matches(value: Variant, answer: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(value) in numbers and typeof(answer) in numbers:
		return is_equal_approx(float(value), float(answer))
	return typeof(value) == typeof(answer) and value == answer
