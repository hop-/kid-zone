class_name TestCase
extends Node
## Base class for every `tests/test_*.gd` file.
##
## The runner (`tests/test_runner.gd`) instances each test script, adds it to the
## scene tree (so `get_tree()` and autoloads are available), and calls every method
## whose name starts with `test_`, in declaration order. A test method may `await`.
## `before_each()` and `after_each()` run around every test method.
##
## A test fails when any assertion fails or a script error happens while it runs.

var _failures: PackedStringArray = []


## Called before every `test_*` method. Override to set up fixtures.
func before_each() -> void:
	pass


## Called after every `test_*` method, even when it failed. Override to clean up.
func after_each() -> void:
	pass


## Passes when `actual` equals `expected`. Numbers compare by value (1 == 1.0);
## values of other different types never match.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _values_equal(actual, expected):
		_fail("expected %s, got %s" % [_repr(expected), _repr(actual)], message)


## Passes when `condition` is true.
func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true, got false", message)


## Passes when `container` (Array, Dictionary key set, String or packed array)
## contains `item`.
func assert_has(container: Variant, item: Variant, message: String = "") -> void:
	var found := false
	match typeof(container):
		TYPE_DICTIONARY:
			found = (container as Dictionary).has(item)
		TYPE_STRING, TYPE_STRING_NAME:
			found = typeof(item) in [TYPE_STRING, TYPE_STRING_NAME] \
					and String(container).contains(String(item))
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
				TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
				TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
				TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			for element: Variant in container:
				if _values_equal(element, item):
					found = true
					break
		_:
			_fail("assert_has: %s is not a container" % type_string(typeof(container)), message)
			return
	if not found:
		_fail("expected %s to contain %s" % [_repr(container), _repr(item)], message)


## The failure messages recorded so far in the current test. Used by the runner.
func get_failures() -> PackedStringArray:
	return _failures


## Clears recorded failures. Used by the runner between test methods.
func clear_failures() -> void:
	_failures = PackedStringArray()


func _fail(reason: String, message: String) -> void:
	_failures.append(reason if message.is_empty() else "%s: %s" % [message, reason])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _values_equal(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return a == b
	if typeof(a) in [TYPE_STRING, TYPE_STRING_NAME] and typeof(b) in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(a) == String(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _repr(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return "\"%s\"" % value
	return "%s (%s)" % [str(value), type_string(typeof(value))]
