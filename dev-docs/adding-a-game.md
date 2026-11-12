# Adding a game, a level or a mode

A new game is a folder under `games/`, a scene whose root script extends
`MiniGame`, one entry in `content/catalog.json`, and its labels in
`content/locale/ui.csv`. Menus, `Router` and `GameShell` don't change: the mode menu
shows a tile for every catalog game, and the shell runs the round.

## The `MiniGame` contract (`core/mini_game.gd`)

```gdscript
class_name MiniGame extends Control
signal choice_made(value)          # emit when the kid taps a choice
signal feedback_done               # emit when show_wrong/show_correct finish
func setup(params: Dictionary, rng: RandomNumberGenerator) -> void
func next_question() -> Dictionary # must contain "answer" and "choices"
func present(question: Dictionary) -> void
func show_wrong(value) -> void     # animate, then emit feedback_done
func show_correct() -> void        # fill the blank, animate, then emit feedback_done
func hop(node: Control) -> void    # helper: a short hop, awaitable
```

How `GameShell` (`core/game_shell.gd`) drives it:

1. It adds the game to its `GameSlot` (full rect), so `@onready` vars are ready,
   then calls `setup()` once. `params` is the catalog game `params` merged with the
   level `params` (a deep copy; the level wins). `rng` is the round's seeded RNG.
2. Per question: `next_question()`, then `present(question)`. The shell compares
   the tapped value with `question["answer"]`: numbers by value (JSON numbers are
   floats), anything else by type and value.
3. Wrong tap: the shell plays `wrong` and calls `show_wrong(value)`. Correct tap: it
   plays `correct`, fills a star and calls `show_correct()`. It waits for
   `feedback_done` either way. Emitting it right away is fine.
4. After `round_length` questions the shell opens round end.

The shell blocks input to the game while feedback runs and until the next question
shows, plays the sounds, and handles stars, back and round end. A game only
presents questions and reports taps. Every base method pushes an error, so override
all five.

Rules for game code:

- Use only the `rng` passed to `setup()`; never global `randi()`, `randf()`,
  `shuffle()` or `pick_random()`. A seed (`--open=<game> --seed=<n>`) then replays
  the same round.
- Put question generation in a pure `RefCounted` class with a `class_name` (like
  `games/math_addition/addition_generator.gd`). It takes the params and the RNG,
  and doesn't touch autoloads, so tests can run it 1000 times.
- Don't repeat the same question twice in a row.
- Use `ChoiceButton` (`ui/choice_button.tscn`) for answers. Connect its
  `chosen(value)` to `choice_made.emit`, and await its `show_wrong()` /
  `show_correct()` animations. It plays `tap` itself. Keep answer buttons at least
  40×32 and touch targets at least 32×32 virtual px.
- No hardcoded English. Numbers and signs are fine; words come from a word pack or
  `tr()`.
- Read sprites with `Art.sprite(id)` and colors with `Art.theme_color(role)` or
  `Content.color(name)`. Use font sizes 9, 18 or 27 (the `LabelLarge` /
  `ButtonLarge` theme variations are 27).
- Set `mouse_filter = 2` (ignore) on layout containers, so they don't eat taps.

## Step by step

This example adds `math_counting` to the math mode: count the apples and tap their
number.

1. **Create `games/math_counting/math_counting.gd`:**

   ```gdscript
   extends MiniGame
   ## Math, counting: count the objects and tap their number.

   const CHOICE_SCENE := preload("res://ui/choice_button.tscn")
   const CHOICE_COUNT := 3

   var _rng: RandomNumberGenerator
   var _max_count := 5
   var _last_count := 0
   var _question: Dictionary = {}

   @onready var _objects: HBoxContainer = %Objects
   @onready var _choices: HBoxContainer = %Choices


   func setup(params: Dictionary, rng: RandomNumberGenerator) -> void:
   	_rng = rng
   	_max_count = maxi(int(params.get("max_count", 5)), 2)
   	for i in CHOICE_COUNT:
   		var button := CHOICE_SCENE.instantiate() as ChoiceButton
   		button.chosen.connect(choice_made.emit)
   		_choices.add_child(button)


   func next_question() -> Dictionary:
   	var count := _rng.randi_range(1, _max_count)
   	if count == _last_count:
   		count = count % _max_count + 1
   	_last_count = count
   	var first := maxi(1, count - _rng.randi_range(0, CHOICE_COUNT - 1))
   	var choices: Array[int] = []
   	for i in CHOICE_COUNT:
   		choices.append(first + i)
   	return {"answer": count, "choices": choices}


   func present(question: Dictionary) -> void:
   	_question = question
   	for child in _objects.get_children():
   		child.queue_free()
   	for i in int(question["answer"]):
   		var rect := TextureRect.new()
   		rect.texture = Art.sprite("apple")
   		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
   		_objects.add_child(rect)
   	var buttons := _buttons()
   	for i in buttons.size():
   		buttons[i].reset()
   		buttons[i].value = question["choices"][i]


   func show_wrong(value: Variant) -> void:
   	var button := _button_for(value)
   	if button != null:
   		await button.show_wrong()
   	feedback_done.emit()


   func show_correct() -> void:
   	var button := _button_for(_question["answer"])
   	if button != null:
   		await button.show_correct()
   	feedback_done.emit()


   func _buttons() -> Array[ChoiceButton]:
   	var buttons: Array[ChoiceButton] = []
   	for child in _choices.get_children():
   		buttons.append(child as ChoiceButton)
   	return buttons


   func _button_for(value: Variant) -> ChoiceButton:
   	for button in _buttons():
   		if button.value == value:
   			return button
   	return null
   ```

   A real game would move `next_question()` into a generator class with tests.

2. **Create `games/math_counting/math_counting.tscn`** in the editor, or by hand. The
   root is a full-rect `Control` with the script, and the containers are marked
   unique (`%Objects`, `%Choices`):

   ```
   [gd_scene load_steps=2 format=3]

   [ext_resource type="Script" path="res://games/math_counting/math_counting.gd" id="1_script"]

   [node name="MathCounting" type="Control"]
   layout_mode = 3
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   mouse_filter = 2
   script = ExtResource("1_script")

   [node name="Layout" type="VBoxContainer" parent="."]
   layout_mode = 1
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   mouse_filter = 2
   theme_override_constants/separation = 16
   alignment = 1

   [node name="Objects" type="HBoxContainer" parent="Layout"]
   unique_name_in_owner = true
   layout_mode = 2
   mouse_filter = 2
   alignment = 1

   [node name="Choices" type="HBoxContainer" parent="Layout"]
   unique_name_in_owner = true
   layout_mode = 2
   mouse_filter = 2
   theme_override_constants/separation = 8
   alignment = 1
   ```

   The shell's top bar (back button and star bar) takes the top 30 px, so the game
   gets the area below it, inset 4 px: 312×146 at 16:9.

3. **Add the catalog entry** to the mode's `games` in `content/catalog.json`. The
   order in the file is the menu order.

   ```json
   {
     "id": "math_counting", "title_key": "GAME_MATH_COUNTING", "icon": "icon_addition",
     "scene": "res://games/math_counting/math_counting.tscn",
     "round_length": 10,
     "params": {"max_count": 5}
   }
   ```

   | Field | Meaning |
   |-------|---------|
   | `id` | lowercase snake_case, unique across all modes; also the folder name |
   | `title_key` | the tile label, a key in `ui.csv` |
   | `icon` | a sprite id (16×16, drawn at 2× on the tile) |
   | `scene` | the game scene; its root must extend `MiniGame` |
   | `round_length` | questions per round, optional, default 10 |
   | `params` | passed to `setup()`, optional |
   | `levels` | optional; without it the mode menu opens the game directly |

4. **Add the label** to `content/locale/ui.csv`, one line per key, with a text for
   every language column:

   ```csv
   GAME_MATH_COUNTING,count
   ```

5. **Give it an icon.** Draw a 16×16 grid in `content/sprites/icons.json` (see
   [art-and-audio.md](art-and-audio.md)), or drop `assets/sprites/<id>.png`. The
   example reuses `icon_addition`.

6. **Check the glyphs.** The font covers a–z, A–Z, 0–9, `! + , - . : = ? _` and
   space. Validation checks the word packs, the digits, `+=?` and the UI strings,
   but not other characters a new game draws. Add any it needs to
   `content/font.json`.

7. **Run the checks:**

   ```bash
   make smoke                                  # content is valid, the scene loads, its root is a MiniGame
   godot --path . -- --open=math_counting --seed=1
   make test
   ```

   `Content` reports catalog problems (a missing scene, a missing title key or icon)
   on startup and in `make smoke`. Add tests for the generator to `tests/`; see
   [testing-and-export.md](testing-and-export.md).

## Adding levels

Add a `levels` array to the game's catalog entry. The game then gets a level select
screen, and `--open=<game>` without a level opens the first one.

```json
"levels": [
  {"id": "easy", "title_key": "LEVEL_EASY", "stars": 1, "params": {"max_count": 5}},
  {"id": "hard", "title_key": "LEVEL_HARD", "stars": 3, "params": {"max_count": 10}}
]
```

- `id` is unique within the game. `stars` (1–3) is how many stars the level tile
  shows. `title_key` must be in `ui.csv`; `LEVEL_EASY`, `LEVEL_MEDIUM` and
  `LEVEL_HARD` already are.
- A level's `params` are merged over the game's `params`, and the level wins.
- Level tiles are 88×90, so three fit in a row at 320 px.

## Adding a mode

Add an entry to `modes` in `content/catalog.json`, with at least one game:

```json
{
  "id": "shapes", "title_key": "MODE_SHAPES", "icon": "icon_shapes", "color": "green",
  "games": [ ... ]
}
```

- `color` is a palette color name (`content/palette.json`), used for the mode's
  tiles. `icon` is a 16×16 sprite id, and `title_key` goes in `ui.csv`.
- The main menu shows the modes as 120×110 tiles in one row, and only two fit in
  320 px. A third mode needs a smaller `TILE_SIZE` in `screens/main_menu.gd`.
  That's the one code change; the mode menu (96×96 tiles in a flow container) needs
  none.
