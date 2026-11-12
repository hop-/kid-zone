extends Node
## Headless test runner. Run with `make test`, which is
## `godot --headless --path . res://tests/run_tests.tscn`.
##
## Finds every `res://tests/test_*.gd` (except this runner and the `TestCase` base),
## runs each `test_*` method of each file, prints a PASS/FAIL line per test and a
## summary, then quits with exit code 1 if anything failed (or no test was found).
## It runs as a scene, so autoloads are loaded.
##
## Optional user arg: `-- --only=<text>` runs only the files whose name contains <text>.
## Tests are discovered with DirAccess, which is fine because tests only run from
## source; they are excluded from exports.

const TESTS_DIR := "res://tests/"
const EXCLUDED_FILES: PackedStringArray = ["test_runner.gd", "test_case.gd"]


## Records script errors raised while a test runs, so a crashing test fails
## instead of silently returning early. `push_error()` and warnings are not
## counted: tests may exercise error paths on purpose.
class ScriptErrorLogger:
	extends Logger

	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		var text := rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("script error: %s (%s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func take_errors() -> PackedStringArray:
		_mutex.lock()
		var errors := _errors
		_errors = PackedStringArray()
		_mutex.unlock()
		return errors


var _logger := ScriptErrorLogger.new()
var _passed := 0
var _failed: PackedStringArray = []


func _ready() -> void:
	OS.add_logger(_logger)
	_run_all.call_deferred()


func _run_all() -> void:
	var only := _arg_value("--only")
	var files := _find_test_files(only)
	print("Running %d test file(s) from %s" % [files.size(), TESTS_DIR])
	for file_name in files:
		await _run_file(file_name)
	OS.remove_logger(_logger)

	var total := _passed + _failed.size()
	print("")
	if total == 0:
		print("FAILED: no tests found")
		get_tree().quit(1)
		return
	if not _failed.is_empty():
		print("Failed tests:")
		for test_id in _failed:
			print("  " + test_id)
	print("%s: %d passed, %d failed, %d total" % [
		"FAILED" if not _failed.is_empty() else "OK", _passed, _failed.size(), total])
	get_tree().quit(1 if not _failed.is_empty() else 0)


func _find_test_files(only: String) -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("cannot open %s: %s" % [TESTS_DIR, error_string(DirAccess.get_open_error())])
		return files
	for file_name in dir.get_files():
		if not file_name.begins_with("test_") or file_name.get_extension() != "gd":
			continue
		if file_name in EXCLUDED_FILES:
			continue
		if not only.is_empty() and not file_name.contains(only):
			continue
		files.append(file_name)
	files.sort()
	return files


func _run_file(file_name: String) -> void:
	var path := TESTS_DIR + file_name
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_record(file_name, "<load>", PackedStringArray(["cannot load or instantiate " + path]))
		return
	var instance: Object = script.new()
	if not instance is TestCase:
		_record(file_name, "<load>", PackedStringArray([path + " does not extend TestCase"]))
		if instance is Node:
			(instance as Node).free()
		return
	var test := instance as TestCase
	test.name = file_name.get_basename()
	add_child(test)
	for method in _test_methods(script):
		_logger.take_errors()
		test.clear_failures()
		await test.before_each()
		await test.call(method)
		await test.after_each()
		var failures := test.get_failures()
		failures.append_array(_logger.take_errors())
		_record(file_name, method, failures)
	remove_child(test)
	test.free()


func _test_methods(script: GDScript) -> PackedStringArray:
	var methods: PackedStringArray = []
	for info: Dictionary in script.get_script_method_list():
		var method_name: String = info["name"]
		if method_name.begins_with("test_") and not method_name in methods:
			methods.append(method_name)
	return methods


func _record(file_name: String, method: String, failures: PackedStringArray) -> void:
	var test_id := "%s::%s" % [file_name, method]
	if failures.is_empty():
		_passed += 1
		print("PASS " + test_id)
		return
	_failed.append(test_id)
	print("FAIL " + test_id)
	for failure in failures:
		print("     " + failure)


func _arg_value(key: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return ""
