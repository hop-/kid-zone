class_name SubtractionGenerator
extends MathPairGenerator
## Generates `a - b = ?` questions for the math subtraction game. The pair pick, the
## object pick and the question shape come from `MathPairGenerator`.
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

## The smallest choice offered: 0 is a valid answer (a - a).
const MIN_CHOICE := 0


func _init(params: Dictionary, object_ids: PackedStringArray, rng: RandomNumberGenerator) -> void:
	super("SubtractionGenerator", "-", MIN_CHOICE, object_ids, rng)
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


func _answer(pair: Vector2i) -> int:
	return pair.x - pair.y
