class_name MissingLetterGenerator
extends QuestionGenerator
## Generates "fill in the missing letter" questions from a locale word pack
## (`content/<locale>/words.json`, already parsed into a Dictionary).
##
## Pure logic: it takes the pack and an injected `RandomNumberGenerator`, never the
## global RNG or an autoload, so the same seed always gives the same sequence.
##
## A distractor letter is only offered when putting it in the blank spells neither a
## pack word nor a `known_words` word (`QuestionUtils.letter_distractors()`), so
## exactly one choice completes a real word. Every pack word counts, even one the
## level leaves out.
##
## Level params (the catalog level's `params`, merged over the game's):
## - `min_length`, `max_length` (optional integers >= 1): only words of this length.
## - `blank`: `"any"` (default) hides any letter the word's `blank` list allows;
##   `"first"` always hides the first letter, and only plays words whose `blank` list
##   allows index 0 (or that have none).
## A filter that leaves fewer than `MIN_WORDS` words is reported and ignored: the
## whole pack is played with `"any"` blanks, so a bad catalog can't empty a round.
## `Content.validate()` checks the catalog's levels with `param_problems()` and
## `filter_words()`.

const BLANK_ANY := "any"
const BLANK_FIRST := "first"
const BLANK_MODES: PackedStringArray = [BLANK_ANY, BLANK_FIRST]
## The params that filter the pack.
const FILTER_PARAMS: PackedStringArray = ["min_length", "max_length", "blank"]
## A filtered level keeps at least this many words, so a word never repeats back to
## back.
const MIN_WORDS := 2

var _rng: RandomNumberGenerator
var _choice_count: int
var _words: Array[Dictionary] = []
var _alphabet: PackedStringArray = []
## Lowercase pack texts and known words; a set (values unused).
var _real_words: Dictionary[String, bool] = {}
var _last_word_index: int = -1
var _first_letter_only := false


func _init(pack: Dictionary, rng: RandomNumberGenerator, choice_count: int = 4,
		params: Dictionary = {}) -> void:
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
	else:
		_apply_filter(params)


## Problems with the filter params (`min_length`, `max_length`, `blank`) in `params`;
## empty when they are valid or absent.
static func param_problems(params: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = []
	if params.has("blank"):
		var blank: Variant = params["blank"]
		if not (blank is String and BLANK_MODES.has(blank)):
			problems.append("'blank' must be \"%s\", got %s"
					% ["\" or \"".join(BLANK_MODES), JSON.stringify(blank)])
	for key in ["min_length", "max_length"]:
		if params.has(key):
			var length: Variant = params[key]
			var is_int := length is int or (length is float and is_finite(length)
					and float(length) == floorf(length))
			if not (is_int and int(length) >= 1):
				problems.append("'%s' must be an integer >= 1, got %s"
						% [key, JSON.stringify(length)])
	return problems


## True when `params` holds any filter param.
static func _has_filter(params: Dictionary) -> bool:
	for key in FILTER_PARAMS:
		if params.has(key):
			return true
	return false


## The entries of `words` a level with these (valid) filter params plays: their
## `text` length is within `min_length`..`max_length`, and with `blank: "first"`
## their `blank` list allows index 0.
static func filter_words(words: Array[Dictionary], params: Dictionary) -> Array[Dictionary]:
	var min_length := int(params.get("min_length", 1))
	var max_length := int(params.get("max_length", 0))
	var first_only := str(params.get("blank", BLANK_ANY)) == BLANK_FIRST
	var result: Array[Dictionary] = []
	for word in words:
		var length := String(word.get("text", "")).length()
		if length < min_length or (params.has("max_length") and length > max_length):
			continue
		if first_only and not allows_blank(word, 0):
			continue
		result.append(word)
	return result


## True when the word's `blank` list (or, without one, any index) allows `index`.
static func allows_blank(word: Dictionary, index: int) -> bool:
	if index < 0 or index >= String(word.get("text", "")).length():
		return false
	if not word.has("blank"):
		return true
	var blank: Variant = word["blank"]
	if not blank is Array:
		return false
	for value: Variant in blank:
		if (value is int or value is float) and int(value) == index:
			return true
	return false


## Narrows `_words` to the level's words, or keeps the whole pack (with any blank)
## when the params are invalid or leave fewer than `MIN_WORDS` words.
func _apply_filter(params: Dictionary) -> void:
	if not _has_filter(params):
		return
	var problems := param_problems(params)
	if not problems.is_empty():
		for problem in problems:
			push_error("MissingLetterGenerator: %s; playing the whole pack" % problem)
		return
	var filtered := filter_words(_words, params)
	if filtered.size() < MIN_WORDS:
		push_error("MissingLetterGenerator: the level params %s leave %d words, need %d; "
				% [params, filtered.size(), MIN_WORDS] + "playing the whole pack")
		return
	_words = filtered
	_first_letter_only = str(params.get("blank", BLANK_ANY)) == BLANK_FIRST


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


## 0 for a `blank: "first"` level; else from the word's `blank` list when it has
## valid entries, else uniform.
func _pick_blank_index(word: Dictionary, text: String) -> int:
	if _first_letter_only:
		return 0
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
