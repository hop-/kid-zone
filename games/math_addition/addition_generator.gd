class_name AdditionGenerator
extends RefCounted
## Generates `a + b = ?` questions for the math addition game.
##
## Pure logic: it takes the level params, the object ids and an injected
## `RandomNumberGenerator`, never the global RNG or an autoload, so the same seed
## always gives the same sequence.
##
## Params (from the catalog level, numbers may be JSON floats):
## - `max_sum`: a + b <= max_sum
## - `max_addend`: a <= max_addend and b <= max_addend
## - `min_sum` (optional): a + b >= min_sum, so a hard level never asks easy sums
## At least one of `max_sum` and `max_addend` is required; every given bound applies.
## Addends are always >= 1.

const CHOICE_COUNT := 4
## The smallest choice offered (addends are >= 1, so every sum is >= 2).
const MIN_CHOICE := 1

var _rng: RandomNumberGenerator
var _object_ids: PackedStringArray
## Every valid [a, b] pair for the level; questions pick uniformly from it.
var _pairs: Array[Vector2i] = []
var _last_pair_index: int = -1


func _init(params: Dictionary, object_ids: PackedStringArray, rng: RandomNumberGenerator) -> void:
	_rng = rng
	_object_ids = object_ids
	if _object_ids.is_empty():
		push_error("AdditionGenerator: no object ids")
	var has_sum := params.has("max_sum")
	var has_addend := params.has("max_addend")
	if not has_sum and not has_addend:
		push_error("AdditionGenerator: params need max_sum or max_addend, got %s" % [params])
		return
	var max_sum := int(params["max_sum"]) if has_sum else 0
	var max_addend := int(params["max_addend"]) if has_addend else 0
	var min_sum := int(params.get("min_sum", 0))
	var top := max_addend if has_addend else max_sum - 1
	for a in range(1, top + 1):
		for b in range(1, top + 1):
			if (has_sum and a + b > max_sum) or a + b < min_sum:
				continue
			_pairs.append(Vector2i(a, b))
	if _pairs.is_empty():
		push_error("AdditionGenerator: no valid addends for params %s" % [params])


## Returns {a, b, answer, choices, object_id, key}. `choices` holds CHOICE_COUNT
## unique ints >= 1, shuffled, one of them the answer. `key` ("a+b") never repeats
## back to back unless the level has only one possible question.
func generate() -> Dictionary:
	if _pairs.is_empty():
		push_error("AdditionGenerator: cannot generate, no valid addends")
		return {}
	var index := _pick_pair_index()
	_last_pair_index = index
	var pair := _pairs[index]
	var answer := pair.x + pair.y
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
		"key": "%d+%d" % [pair.x, pair.y],
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
