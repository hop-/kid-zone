# Testing and export

Run everything from the project root. Each `make` target that needs the import
cache (the CSV translation and the global class cache) depends on the stamp
`.godot/.make-imported`, which runs `godot --headless --path . --import` whenever a
file under the game folders or `tests/` changes.

## The test runner

```bash
make test                                                          # all tests
godot --headless --path . res://tests/run_tests.tscn -- --only=content   # files whose name contains "content"
```

`make test` runs `godot --headless --path . res://tests/run_tests.tscn`. The runner
(`tests/test_runner.gd`) is a scene, so all the autoloads are loaded.

- **Discovery:** every `res://tests/test_*.gd` file, sorted by name, except the
  runner itself and `test_case.gd`. Each file must extend `TestCase`. Every method
  whose name starts with `test_` runs, in declaration order.
- **Per test:** the runner adds the test file's node to the tree, then calls
  `before_each()`, the test, and `after_each()`. Each of them may `await`.
- **Failure:** a failed assertion, or a script error (a runtime error in GDScript)
  while the test runs. `push_error()` and `push_warning()` don't fail a test, so
  error paths can be tested. A file that can't load or doesn't extend `TestCase`
  fails as `<file>::<load>`.
- **Output:** one `PASS`/`FAIL <file>::<method>` line per test with the failure
  messages, then `OK: N passed, 0 failed, N total` or `FAILED: ...` and the list of
  failed tests. The exit code is 1 when anything failed or no test was found.

Today `tests/test_sanity.gd` checks the runner itself.

### `TestCase` (`tests/test_case.gd`)

| Method | Passes when |
|--------|-------------|
| `assert_eq(actual, expected, message := "")` | equal; numbers compare by value (`2 == 2.0`), `String` and `StringName` compare by text, other different types never match |
| `assert_true(condition, message := "")` | `condition` is true |
| `assert_has(container, item, message := "")` | an Array or packed array contains `item`, a Dictionary has the key, or a String contains the substring |

Override `before_each()` and `after_each()` for setup and cleanup.

### Writing tests

```gdscript
extends TestCase

const TEMP_SETTINGS := "user://test_settings.cfg"


func after_each() -> void:
	Settings.load_from(Settings.DEFAULT_PATH)  # only reads the real file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS))


func test_easy_sums_stay_small() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var generator := AdditionGenerator.new({"max_sum": 5}, PackedStringArray(["apple"]), rng)
	for i in 1000:
		var question := generator.generate()
		assert_true(question["a"] + question["b"] <= 5, "sum of %s" % question["key"])
		assert_has(question["choices"], question["answer"])


func test_sound_toggle_mutes_the_sfx_bus() -> void:
	Settings.load_from(TEMP_SETTINGS)
	Settings.sfx_on = false
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")))
```

- **Never touch the real `user://settings.cfg`.** The `Settings` autoload saves to
  it on every change. Point it at a temp file first with
  `Settings.load_from("user://test_settings.cfg")`, restore it with
  `Settings.load_from(Settings.DEFAULT_PATH)` (which only reads), and delete the
  temp file. A fresh `preload("res://autoload/settings.gd").new()` has no path and
  never saves.
- **Pure logic** (`RoundController`, `AdditionGenerator`, `MissingLetterGenerator`)
  takes a seeded `RandomNumberGenerator`, so tests can run 1000 questions and
  compare two runs with the same seed.
- **Fixtures:** `Content`, `Art` and `Audio` can be separate instances:
  `preload("res://autoload/content.gd").new()` then `load_content(<root>)` for a
  fixture content folder; `Art`'s `override_root` and `content`; `Audio`'s
  `sfx_root`, `music_root` and `content`. Free them afterwards. Put fixture files
  under `tests/` (exports leave `tests/` out) or write them to `user://` and delete
  them. To reload the `Content` autoload from a fixture root, restore it with
  `Content.load_content()`.
- **Screens:** attach `Router` to your own host `Control`
  (`Router.attach(host)`), set `Router.fade_duration = 0.0` so screens switch at
  once, and optionally stand in a scene with `Router.scenes["game"] = <path>`.
  Restore with `Router.detach()`, `Router.fade_duration = Router.DEFAULT_FADE_DURATION`
  and `Router.scenes = Router.DEFAULT_SCENES.duplicate()`. Menu screens and round end
  have `tiles()`; press one with `tile.pressed.emit()`. `GameShell` takes a `seed`
  param and has `game()`, `controller()`, `star_bar()`, `current_question()` and
  `is_input_locked()`; both games have `choice_buttons()`.
- **Sound in tests:** stop any player you started and wait about 0.15 s before the
  test ends. Otherwise Godot may print "ObjectDB instances were leaked" at exit
  (the tests still pass).
- `main.gd` has static helpers for tests: `parse_args(args)`, `sample_stars(count)`
  and `smoke_problems()`.

## Smoke tests

```bash
make smoke                     # godot --headless --path . -- --smoke-test
make smoke-export BUILD=debug  # export build/debug/linux/kid-zone, then run it with -- --smoke-test
```

The smoke check (`main.gd`, `smoke_problems()`) uses the autoloads, so it checks
what the game would use:

- `Content.validate()` is empty
- the pixel font builds, has every required glyph, and is the theme's font
- every grid sprite builds at its grid size
- every sound effect synthesizes (or loads) with a length above 0
- every Router scene and catalog game scene loads, and each game's root is a
  `MiniGame`

It prints `SMOKE OK` and exits 0, or prints `SMOKE FAILED` and one problem per line
to stderr and exits 1. `make smoke-export` proves the JSON content and the
translation are inside the exported game data.

## Debug options

User args after `--`, both when running from source and in exported builds. Any
of them stops the game from saving settings for that run.

| Option | Opens |
|--------|-------|
| `--smoke-test` | the smoke check above, then quits |
| `--open=<game_id>[:<level_id>]` | that game, at its first level when none is given |
| `--seed=<n>` | with `--open`: a fixed seed, so the same questions come |
| `--screen=main_menu` | the main menu |
| `--screen=mode_menu:<mode_id>` | a mode menu (`math`, `words`) |
| `--screen=level_select:<game_id>` | level select of a game with levels |
| `--screen=round_end[:<game_id>[:<level_id>]]` | round end with sample stars (gold, every fourth silver); defaults to the first game and level |

`--open` and `--screen` build the back stack a kid would have, so back works as in
play. On success the game prints a line like
`debug: opened main_menu > mode_menu > level_select > game (seed 3)`. A bad option
or id prints the problem and the usage, and exits 1. Unknown options only warn.

## Screenshots

Screenshots need a display: headless runs don't render, and they don't scale touch
or mouse coordinates to the 320×180 view, so check touch layout in a windowed run
too. Save screenshots outside the repo.

At 16:9, Movie Maker works:

```bash
godot --path . --resolution 1280x720 --write-movie /tmp/shots/shot.png \
  --fixed-fps 10 --quit-after 15 -- --open=math_addition:hard --seed=3
```

It writes numbered frames (`shot00000000.png`, ...) at 320×180. Movie Maker always
records a 320×180 crop, though, so on 4:3 and 16:10 it hides the extra area. For
those, save the root viewport's texture instead, with a small script kept outside
the repo:

```gdscript
# shot.gd: opens the main scene, waits 30 frames, saves the view to $SHOT, quits.
extends SceneTree

var _frames := 0


func _initialize() -> void:
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
		quit()
	return false
```

```bash
SHOT=/tmp/shots/mode_4x3.png godot --path . --resolution 1024x768 \
  --script /tmp/shots/shot.gd -- --screen=mode_menu:math
```

At 1024×768 that saves a 320×240 image. Check the main menu, both mode menus, level
select, both games and round end at 1280×720, 1024×768 and 1280×800.

## Exports

`export_presets.cfg` has five presets: `Linux`, `Windows`, `macOS`, `Android` and
`iOS`.

- Every preset has `include_filter="*.json"`, because the content is JSON, which
  Godot doesn't export by default, and `exclude_filter="tests/*,tools/*"`. The
  `ui.csv` source isn't packed; its imported translation is.
- `export_path` is `build/release/<platform>/kid-zone...`. The Makefile passes its
  own path, `build/<BUILD>/<platform>/...`, and uses `--export-release` or
  `--export-debug` from `BUILD`.
- Linux and Windows are x86_64 with the game data embedded. macOS is a universal
  `.app` in a `.zip`, ad-hoc signed and not notarized. Android is an APK for
  armeabi-v7a and arm64-v8a (no Gradle build), signed, immersive. iOS exports only
  the Xcode project, for iPhone and iPad (`application/targeted_device_family=2`).
- Ids: Android `io.github.hop_.kidzone`, macOS and iOS `io.github.hop-.kid-zone`.

| Target | Output in `build/<BUILD>/` |
|--------|---------------------------|
| `make linux` | `linux/kid-zone` |
| `make windows` | `windows/kid-zone.exe` (debug also writes `kid-zone.console.exe`) |
| `make macos` | `macos/kid-zone.zip` |
| `make android` | `android/kid-zone.apk` |
| `make ios` | `ios/kid-zone.xcodeproj` and the files next to it |
| `make dist` | `kid-zone-linux-x86_64.tar.gz`, `kid-zone-windows-x86_64.zip`, `kid-zone-macos-universal.zip`, `kid-zone-android.apk`, `kid-zone-ios-xcode-project.zip` |

- `PLATFORMS` (default `linux windows macos android ios`) picks what `make all` and
  `make dist` build. For example, the full debug set without iOS is
  `make all BUILD=debug PLATFORMS="linux windows macos android"`.
- An export reruns only when a game file changes. `make icon` always rewrites
  `icon.svg`, so it triggers a re-export.
- `check-templates`, `check-android` and `check-ios` run first and stop with a clear
  message: missing export templates (`make templates`), no Android toolchain
  (`make android-setup`), a release APK without a key (`.env`, see the README), or
  no Apple Team ID in `export_presets.cfg`.
- The headless import and export steps may print
  `cannot connect to daemon at tcp:5037`. It's adb looking for Android devices, and
  it's harmless.

The README's "Building" section covers templates, Android setup, release signing
with `.env`, and the macOS and iOS notes.
