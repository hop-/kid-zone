extends MathEquationGame
## Math, subtraction: `a - b = ?` on the shared equation layout (`MathEquationGame`),
## with a objects above `a` and b objects above `b`. Questions come from
## `SubtractionGenerator` with the level params (`max_minuend`, and optionally
## `min_minuend`).


func _make_generator(params: Dictionary, object_ids: PackedStringArray,
		rng: RandomNumberGenerator) -> RefCounted:
	return SubtractionGenerator.new(params, object_ids, rng)


func _operator_text() -> String:
	return "-"
