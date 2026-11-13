class_name AdditionGenerator
extends MathPairGenerator
## Generates `a + b = ?` questions for the math addition game. The pair pick, the
## object pick and the question shape come from `MathPairGenerator`.
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

## The smallest choice offered (addends are >= 1, so every sum is >= 2).
const MIN_CHOICE := 1


func _init(params: Dictionary, object_ids: PackedStringArray, rng: RandomNumberGenerator) -> void:
	super("AdditionGenerator", "+", MIN_CHOICE, object_ids, rng)
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


func _answer(pair: Vector2i) -> int:
	return pair.x + pair.y
