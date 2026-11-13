class_name MissingLetterGenerator
extends RefCounted
## Generates "fill in the missing letter" questions from a locale word pack
## (`content/<locale>/words.json`, already parsed into a Dictionary).
##
## Pure logic: it takes the pack and an injected `RandomNumberGenerator`, never the
## global RNG or an autoload, so the same seed always gives the same sequence.
##
## A distractor letter is only offered when putting it in the blank spells neither a
## pack word nor a `known_words` word (`QuestionUtils.letter_distractors()`), so
## exactly one choice completes a real word.

var _rng: RandomNumberGenerator
var _choice_count: int
var _words: Array[Dictionary] = []
var _alphabet: PackedStringArray = []
## Lowercase pack texts and known words; a set (values unused).
var _real_words: Dictionary[String, bool] = {}
var _last_word_index: int = -1


func _init(pack: Dictionary, rng: RandomNumberGenerator, choice_count: int = 4) -> void:
	_rng = rng
	if choice_count < 2:
		push_error("MissingLetterGenerator: choice_count must be >= 2, got %d; using 2" % choice_count)
		choice_count = 2
	_choice_count = choice_count
	for letter in String(pack.get("alphabet", "")):
		if not _alphabet.has(letter):
			_alphabet.append(letter)
	for entry: Variant in pack.get("words", []):
		if entry is Dictionary and not String(entry.get("text", "")).is_empty():
			_words.append(entry)
			_real_words[String(entry["text"]).to_lower()] = true
		else:
			push_error("MissingLetterGenerator: skipping invalid word entry %s" % [entry])
	for known: Variant in pack.get("known_words", []):
		_real_words[String(known).to_lower()] = true
	if _words.is_empty():
		push_error("MissingLetterGenerator: the word pack has no words")


## Returns {word_id, text, picture, blank_index, answer, choices, key}. `choices`
## holds `choice_count` unique alphabet letters, shuffled, one of them the answer.
## The word never repeats back to back unless the pack has only one word.
func generate() -> Dictionary:
	if _words.is_empty():
		push_error("MissingLetterGenerator: cannot generate, no words")
		return {}
	var index := _pick_word_index()
	_last_word_index = index
	var word := _words[index]
	var text := String(word["text"])
	var word_id := String(word.get("id", text))
	var blank_index := _pick_blank_index(word, text)
	var answer := text[blank_index]
	return {
		"word_id": word_id,
		"text": text,
		"picture": String(word.get("picture", "")),
		"blank_index": blank_index,
		"answer": answer,
		"choices": _build_choices(text, blank_index, answer),
		"key": "%s:%d" % [word_id, blank_index],
	}


## Uniform over all words except the previous one.
func _pick_word_index() -> int:
	var count := _words.size()
	if count == 1 or _last_word_index < 0:
		return _rng.randi_range(0, count - 1)
	var index := _rng.randi_range(0, count - 2)
	if index >= _last_word_index:
		index += 1
	return index


## From the word's `blank` list when it has valid entries, else uniform.
func _pick_blank_index(word: Dictionary, text: String) -> int:
	var allowed: Array[int] = []
	for value: Variant in word.get("blank", []):
		var blank := int(value)
		if blank >= 0 and blank < text.length() and not allowed.has(blank):
			allowed.append(blank)
		else:
			push_error("MissingLetterGenerator: word '%s' has invalid blank %s" % [text, value])
	if allowed.is_empty():
		return _rng.randi_range(0, text.length() - 1)
	return allowed[_rng.randi_range(0, allowed.size() - 1)]


func _build_choices(text: String, blank_index: int, answer: String) -> Array[String]:
	var candidates := QuestionUtils.letter_distractors(text, blank_index, _alphabet, _real_words)
	var needed := _choice_count - 1
	if candidates.size() < needed:
		push_error("MissingLetterGenerator: only %d valid distractors for '%s' blank %d, need %d"
				% [candidates.size(), text, blank_index, needed])
	QuestionUtils.shuffle(candidates, _rng)
	var choices: Array[String] = [answer]
	choices.append_array(candidates.slice(0, needed))
	QuestionUtils.shuffle(choices, _rng)
	return choices
