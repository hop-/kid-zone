class_name RoundController
extends RefCounted
## Round bookkeeping for one play-through of a mini-game: how many questions are
## answered, and which star each one earned (from the taps it took).
##
## Pure logic: no scenes, no autoloads. GameShell calls `start()` once per round,
## then `submit(correct)` for every answer tap until `is_done()`.
##
## A question ends on its first correct submit. Its star is gold when that was the
## first try, silver when it took retries. Wrong submits only count attempts.

enum Star { EMPTY, GOLD, SILVER }

var _round_length: int = 0
var _stars: Array[Star] = []
var _current_attempts: int = 0


## Starts a new round of `round_length` questions, clearing the previous one.
func start(round_length: int) -> void:
	if round_length < 1:
		push_error("RoundController: round_length must be >= 1, got %d; using 1" % round_length)
		round_length = 1
	_round_length = round_length
	_stars.clear()
	_current_attempts = 0


## Records one answer tap on the current question. Returns false (and changes
## nothing) when the round is done or was never started.
func submit(correct: bool) -> bool:
	if is_done():
		return false
	_current_attempts += 1
	if correct:
		_stars.append(Star.GOLD if _current_attempts == 1 else Star.SILVER)
		_current_attempts = 0
	return true


## True once every question of the round is answered correctly (and before `start`).
func is_done() -> bool:
	return _stars.size() >= _round_length


func get_round_length() -> int:
	return _round_length


## 0-based index of the current question; equals `get_round_length()` when done.
func question_index() -> int:
	return _stars.size()


## The star of each answered question, in order (GOLD or SILVER).
func stars() -> Array[Star]:
	return _stars.duplicate()
