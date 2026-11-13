extends MathEquationGame
## Math, subtraction: `a - b = ?` on the shared equation layout (`MathEquationGame`),
## with a objects above `a` and b red ✕ marks (`mark_x`) above `b`. Questions come from
## `SubtractionGenerator` with the level params (`max_minuend`, and optionally
## `min_minuend`).

## The sprite drawn b times above `b`.
const MARK_SPRITE := "mark_x"


func _make_generator(params: Dictionary, object_ids: PackedStringArray,
		rng: RandomNumberGenerator) -> QuestionGenerator:
	return SubtractionGenerator.new(params, object_ids, rng)


func _operator_text() -> String:
	return "-"


## The b being taken away are drawn as red ✕ marks, not as objects.
func _group_b_sprite(_question: Dictionary) -> Texture2D:
	return Art.sprite(MARK_SPRITE)
