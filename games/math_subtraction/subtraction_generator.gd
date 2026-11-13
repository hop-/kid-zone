class_name SubtractionGenerator
extends RefCounted
## Generates `a - b = ?` questions for the math subtraction game.
##
## Pure logic: it takes the level params, the object ids and an injected
## `RandomNumberGenerator`, never the global RNG or an autoload, so the same seed
## always gives the same sequence.
##
## Params (from the catalog level, numbers may be JSON floats):
## - `max_minuend` (required): a <= max_minuend
## - `min_minuend` (optional): a >= min_minuend, so a hard level never asks easy
##   questions
## The minuend is always >= 1, the subtrahend b is in [1, a], and the answer a - b is
## always >= 0.

const CHOICE_COUNT := 4
## The smallest choice offered: 0 is a valid answer (a - a).
const MIN_CHOICE := 0

var _rng: RandomNumberGenerator
var _object_ids: PackedStringArray
## Every valid [a, b] pair for the level; questions pick uniformly from it.
var _pairs: Array[Vector2i] = []
var _last_pair_index: int = -1


func _init(params: Dictionary, object_ids: PackedStringArray, rng: RandomNumberGenerator) -> void:
	_rng = rng
	_object_ids = object_ids
	if _object_ids.is_empty():
		push_error("SubtractionGenerator: no object ids")
	if not params.has("max_minuend"):
		push_error("SubtractionGenerator: params need max_minuend, got %s" % [params])
		return
	var max_minuend := int(params["max_minuend"])
	var min_minuend := maxi(int(params.get("min_minuend", 1)), 1)
	for a in range(min_minuend, max_minuend + 1):
		for b in range(1, a + 1):
			_pairs.append(Vector2i(a, b))
	if _pairs.is_empty():
		push_error("SubtractionGenerator: no valid minuends for params %s" % [params])


## Returns {a, b, answer, choices, object_id, key}. `choices` holds CHOICE_COUNT
## unique ints >= 0, shuffled, one of them the answer. `key` ("a-b") never repeats
## back to back unless the level has only one possible question.
func generate() -> Dictionary:
	if _pairs.is_empty():
		push_error("SubtractionGenerator: cannot generate, no valid minuends")
		return {}
	var index := _pick_pair_index()
	_last_pair_index = index
	var pair := _pairs[index]
	var answer := pair.x - pair.y
	var object_id := ""
	if not _object_ids.is_empty():
		object_id = _object_ids[_rng.randi_range(0, _object_ids.size() - 1)]
	return {
		"a": pair.x,
		"b": pair.y,
		"answer": answer,
		"choices": QuestionUtils.number_choices(answer, CHOICE_COUNT, MIN_CHOICE,
				QuestionUtils.NO_MAX, _rng),
		"object_id": object_id,
		"key": "%d-%d" % [pair.x, pair.y],
	}


## Uniform over all pairs except the previous one.
func _pick_pair_index() -> int:
	var count := _pairs.size()
	if count == 1 or _last_pair_index < 0:
		return _rng.randi_range(0, count - 1)
	var index := _rng.randi_range(0, count - 2)
	if index >= _last_pair_index:
		index += 1
	return index
