extends MathEquationGame
## Math, addition: `a + b = ?` on the shared equation layout (`MathEquationGame`).
## Questions come from `AdditionGenerator` with the level params (`max_sum` and/or
## `max_addend`, and optionally `min_sum`).


func _make_generator(params: Dictionary, object_ids: PackedStringArray,
		rng: RandomNumberGenerator) -> RefCounted:
	return AdditionGenerator.new(params, object_ids, rng)


func _operator_text() -> String:
	return "+"
