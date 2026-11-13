class_name QuestionUtils
extends RefCounted
## Shared pure helpers for the question generators and content validation: a shuffle
## with an injected RNG, the number-choice rule of the math games and the
## letter-distractor rule of the missing-letter game.
##
## Static only, no state, and no autoloads, so generators stay pure and a seed always
## gives the same sequence.

## Number distractors start at answer ± 1..NEAR_RANGE, and widen outward only when
## needed.
const NEAR_RANGE := 3
## `number_choices()` with this `max_value` has no upper bound.
const NO_MAX := 9223372036854775807


## Fisher–Yates with the injected RNG (Array.shuffle() uses the global one).
static func shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


## `count` unique ints in [min_value, max_value], shuffled, one of them `answer`.
## Distractors are picked from answer ± 1..NEAR_RANGE; past that the range widens one
## step at a time until there are enough. Fewer come back (with an error) only when
## the bounds leave too few values.
static func number_choices(answer: int, count: int, min_value: int, max_value: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var needed := count - 1
	var candidates: Array[int] = []
	var distance := 1
	while distance <= NEAR_RANGE or candidates.size() < needed:
		var lower := answer - distance
		var upper := answer + distance
		if lower < min_value and upper > max_value:
			break
		if lower >= min_value:
			candidates.append(lower)
		if upper <= max_value:
			candidates.append(upper)
		distance += 1
	if candidates.size() < needed:
		push_error("QuestionUtils: only %d choices besides %d fit in [%d, %d], need %d"
				% [candidates.size(), answer, min_value, max_value, needed])
	shuffle(candidates, rng)
	var choices: Array[int] = [answer]
	choices.append_array(candidates.slice(0, needed))
	shuffle(choices, rng)
	return choices


## True when `letter` in the blank at `blank_index` of `text` spells a word in
## `real_words` (a set of lowercase words; values unused).
static func spells_real_word(text: String, blank_index: int, letter: String,
		real_words: Dictionary) -> bool:
	var spelled := (text.left(blank_index) + letter + text.substr(blank_index + 1)).to_lower()
	return real_words.has(spelled)


## The alphabet letters, in alphabet order, that can be offered as wrong answers for
## the blank at `blank_index` of `text`: every letter except the answer that doesn't
## spell a word in `real_words` (the lowercase pack words and known words).
static func letter_distractors(text: String, blank_index: int, alphabet: PackedStringArray,
		real_words: Dictionary) -> Array[String]:
	var answer := text[blank_index]
	var letters: Array[String] = []
	for letter in alphabet:
		if letter != answer and not spells_real_word(text, blank_index, letter, real_words):
			letters.append(letter)
	return letters
