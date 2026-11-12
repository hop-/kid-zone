extends TestCase
## Proves the runner itself works: discovery, assertions and async tests.


func test_assert_eq() -> void:
	assert_eq(1 + 1, 2)
	assert_eq(2, 2.0, "int and float compare by value")
	assert_eq("kid", &"kid", "String and StringName compare by value")


func test_assert_true() -> void:
	assert_true(true)


func test_assert_has() -> void:
	assert_has([1, 2, 3], 2)
	assert_has({"a": 1}, "a")
	assert_has("sun", "u")
	assert_has(PackedStringArray(["x", "y"]), "y")


func test_failing_assertions_are_recorded() -> void:
	assert_eq(1, 2)
	assert_eq(1, "1")
	assert_true(false)
	assert_has([1, 2], 3)
	var recorded := get_failures().size()
	clear_failures()
	assert_eq(recorded, 4, "every failed assertion is recorded")


func test_runs_in_scene_tree() -> void:
	assert_true(is_inside_tree())
	await get_tree().process_frame
	assert_true(is_inside_tree(), "await works inside a test")
