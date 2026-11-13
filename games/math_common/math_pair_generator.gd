class_name MathPairGenerator
extends QuestionGenerator
## The shared base of the `a <op> b = ?` generators (`AdditionGenerator`,
## `SubtractionGenerator`): the level's list of valid `(a, b)` pairs, the uniform
## no-repeat pair pick, the object pick and the question shape.
##
## A subclass calls `super(...)` first in its `_init()`, with its name, operator sign
## and smallest choice, then appends every valid pair for its level params to
## `_pairs`, and overrides `_answer()`.
##
## Pure logic: it takes the object ids and an injected `RandomNumberGenerator`, never
## the global RNG or an autoload, so the same seed always gives the same sequence.
## Per question the RNG is drawn in this order: the pair, the object, the choices.

const CHOICE_COUNT := 4

var _rng: RandomNumberGenerator
var _object_ids: PackedStringArray
## Every valid [a, b] pair for the level; the subclass fills it in `_init()`, and
## questions pick uniformly from it.
var _pairs: Array[Vector2i] = []
var _last_pair_index: int = -1
## The subclass name, for error messages.
var _name: String
## The operator sign in the question `key`, such as "+".
var _operator_sign: String
## The smallest choice offered.
var _min_choice: int


func _init(generator_name: String, operator_sign: String, min_choice: int,
		object_ids: PackedStringArray, rng: RandomNumberGenerator) -> void:
	_name = generator_name
	_operator_sign = operator_sign
	_min_choice = min_choice
	_rng = rng
	_object_ids = object_ids
	if _object_ids.is_empty():
		push_error("%s: no object ids" % _name)


## Returns {a, b, answer, choices, object_id, key}. `choices` holds CHOICE_COUNT
## unique ints >= the subclass's smallest choice, shuffled, one of them the answer.
## `key` ("a<sign>b") never repeats back to back unless the level has only one
## possible question.
func generate() -> Dictionary:
	if _pairs.is_empty():
		push_error("%s: cannot generate, no valid pairs" % _name)
		return {}
	var index := _pick_pair_index()
	_last_pair_index = index
	var pair := _pairs[index]
	var answer := _answer(pair)
	var object_id := ""
	if not _object_ids.is_empty():
		object_id = _object_ids[_rng.randi_range(0, _object_ids.size() - 1)]
	return {
		"a": pair.x,
		"b": pair.y,
		"answer": answer,
		"choices": QuestionUtils.number_choices(answer, CHOICE_COUNT, _min_choice,
				QuestionUtils.NO_MAX, _rng),
		"object_id": object_id,
		"key": "%d%s%d" % [pair.x, _operator_sign, pair.y],
	}


## Virtual: the answer to `pair.x <op> pair.y`.
func _answer(_pair: Vector2i) -> int:
	push_error("%s does not override _answer()" % _name)
	return 0


## Uniform over all pairs except the previous one.
func _pick_pair_index() -> int:
	var count := _pairs.size()
	if count == 1 or _last_pair_index < 0:
		return _rng.randi_range(0, count - 1)
	var index := _rng.randi_range(0, count - 2)
	if index >= _last_pair_index:
		index += 1
	return index
