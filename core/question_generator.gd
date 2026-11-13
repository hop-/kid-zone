class_name QuestionGenerator
extends RefCounted
## The base of every game's question generator.
##
## A generator is pure logic: it takes its params and an injected
## `RandomNumberGenerator` (in its own `_init()`), never the global RNG or an
## autoload, so the same seed always gives the same sequence. A game calls
## `generate()` once per question.


## Virtual: the next question, a Dictionary with at least `answer` and `choices`, or
## an empty Dictionary when the generator can't make one.
func generate() -> Dictionary:
	push_error("QuestionGenerator: %s does not override generate()" % [get_script().resource_path])
	return {}
