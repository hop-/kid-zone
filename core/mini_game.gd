class_name MiniGame
extends Control
## The contract between `GameShell` and a game scene. A game's root script extends
## `MiniGame`; the shell does everything else (top bar, stars, sounds, input locking,
## the round loop and round end).
##
## The shell adds the game to its content slot (so `@onready` vars are ready), then
## calls `setup(params, rng)` once, and for every question of the round:
## 1. `next_question()`: returns a Dictionary with at least `answer` and `choices`.
## 2. `present(question)`: shows it, with tappable choices that emit
##    `choice_made(value)`.
## 3. On a wrong tap, `show_wrong(value)`; on the correct one, `show_correct()`. Both
##    run their animation and then emit `feedback_done`, which the shell awaits.
##    Emitting it right away (no animation) is fine too.
##
## The shell plays the `wrong` and `correct` sounds and blocks input to the game
## while feedback runs, so games don't need to. The base implementations push an
## error: a game must override all five methods.

## Emitted when the kid taps a choice, with that choice's value.
signal choice_made(value: Variant)
## Emitted when a `show_wrong()` or `show_correct()` animation has finished.
signal feedback_done

## How far `hop()` lifts a node, and how long each half of the hop takes.
const HOP_HEIGHT := 4
const HOP_TIME := 0.08


## Called once, after the game is in the tree: `params` are the catalog game params
## merged with the level params, and `rng` is the round's seeded generator. Use only
## `rng` for randomness, so a seed replays the same round.
func setup(_params: Dictionary, _rng: RandomNumberGenerator) -> void:
	_not_overridden("setup")


## The next question: a Dictionary with at least `answer` and `choices`.
func next_question() -> Dictionary:
	_not_overridden("next_question")
	return {}


## Shows `question` and makes its choices tappable.
func present(_question: Dictionary) -> void:
	_not_overridden("present")


## Marks the wrongly chosen `value` (shake, grey, disabled), then emits
## `feedback_done`.
func show_wrong(_value: Variant) -> void:
	_not_overridden("show_wrong")
	feedback_done.emit()


## Fills the blank with the answer and plays a short celebration, then emits
## `feedback_done`.
func show_correct() -> void:
	_not_overridden("show_correct")
	feedback_done.emit()


## A short hop of `node` (up `HOP_HEIGHT` px and back), for games to use in
## `show_correct()`. Await it to wait for the landing.
func hop(node: Control) -> void:
	var rest_y := node.position.y
	var tween := node.create_tween()
	tween.tween_property(node, ^"position:y", rest_y - HOP_HEIGHT, HOP_TIME)
	tween.tween_property(node, ^"position:y", rest_y, HOP_TIME)
	await tween.finished


func _not_overridden(method: String) -> void:
	push_error("MiniGame: %s does not override %s()" % [get_script().resource_path, method])
