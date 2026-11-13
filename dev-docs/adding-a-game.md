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
  `shuffle()` or `pick_random()`. Use `QuestionUtils.shuffle(array, rng)` to
  shuffle. A seed (`--open=<game> --seed=<n>`) then replays the same round.
- Put question generation in a pure class with a `class_name` that extends
  `QuestionGenerator` (like `games/math_subtraction/subtraction_generator.gd`). It
  takes the params and the RNG, and doesn't touch autoloads, so a probe or a test
  can run it 1000 times.
- Don't repeat the same question twice in a row.
- Show the answers in a `ChoiceRow` (`ui/choice_row.tscn`) instead of building
  buttons yourself. Keep answer buttons at least 40×32 and touch targets at least
  32×32 virtual px.
- No hardcoded English. Numbers and signs are fine; words come from a word pack or
  `tr()`.
- Read sprites with `Art.sprite(id)` and colors with `Art.theme_color(role)` or
  `Content.color(name)`. Use font sizes 9, 18 or 27 (the `LabelLarge` /
  `ButtonLarge` theme variations are 27).
- Set `mouse_filter = 2` (ignore) on layout containers, so they don't eat taps.

## Shared parts

Use these instead of copying code from another game.

### `ChoiceRow` (`ui/choice_row.gd` + `.tscn`)

A centered `HBoxContainer` of `ChoiceButton`s, 8 px apart. Every game uses one for
its answers.

```gdscript
class_name ChoiceRow extends HBoxContainer
signal chosen(value)                    # a button was tapped; connect it to choice_made.emit
func set_choices(values: Array, button_size: Vector2, texts: Array = []) -> void
func buttons() -> Array[ChoiceButton]   # in screen order
func button_for(value) -> ChoiceButton  # same type and value, or null
func show_wrong(value) -> void          # shake + grey out that button; awaitable
func show_correct(value) -> void        # green + hop; awaitable
```

- `set_choices()` shows one button per value, reuses the buttons it has, resets
  them, and sizes them to `button_size`. A button's text is `str(value)`, or the
  entry of `texts` at the same index. The word game passes uppercase `texts` and
  keeps the lowercase letters as `values`, so the value a tap reports doesn't
  depend on the letter case.
- A `ChoiceButton` plays `tap` itself. The wrong and correct sounds belong to the
  shell.

### `QuestionUtils` (`core/question_utils.gd`)

Static, pure helpers for generators and for `Content` validation:

| Function | Does |
|----------|------|
| `shuffle(values, rng)` | Fisher–Yates with the injected RNG |
| `number_choices(answer, count, min_value, max_value, rng)` | `count` unique shuffled ints in `[min_value, max_value]` (inclusive), one of them `answer`. Distractors come from `answer ± 1..3` (`NEAR_RANGE`) and widen outward only when the bounds cut those off. Pass `QuestionUtils.NO_MAX` for no upper bound. |
| `spells_real_word(text, blank_index, letter, real_words)` | true when `letter` in the blank spells a word in `real_words` |
| `letter_distractors(text, blank_index, alphabet, real_words)` | the letters that may be offered as wrong answers: every alphabet letter except the answer that spells no real word |

The math generators use `number_choices()`. `MissingLetterGenerator` and
`Content.count_distractors()` both use `letter_distractors()`, so the game and
validation apply the same rule.

### `QuestionGenerator` (`core/question_generator.gd`)

The base of every game's question generator:

```gdscript
class_name QuestionGenerator extends RefCounted
func generate() -> Dictionary   # virtual: the next question, or {} when it can't make one
```

A generator takes its params and the injected RNG in its own `_init()`, so the base
has no constructor arguments. The base `generate()` pushes an error and returns
`{}`, so override it. `AdditionGenerator` and `SubtractionGenerator` extend it
through `MathPairGenerator` (below), and `MissingLetterGenerator` extends it
directly. A game can then type its generator as `QuestionGenerator` and call
`generate()` on it.

### `MathEquationGame` (`games/math_common/`)

The view of an `a <op> b = ?` math game. `math_equation_game.gd`
(`class_name MathEquationGame extends MiniGame`) implements all five `MiniGame`
methods, and `math_equation.tscn` is its layout:

- `a` identical objects above `a` (one random object per question), and `b` more
  above `b`, in rows of 5 (`ROW_LENGTH`), each group 8 px above its number (the
  `ColumnA` / `ColumnB` separation). Group b draws `_group_b_sprite()`, which is the
  same object by default; subtraction draws red ✕ marks instead.
- the operator label (`%Operator`), `=`, and a `?` blank that shows the answer in
  green on a correct tap
- a `ChoiceRow` (`%Choices`) with 48×36 buttons

A math game inherits the scene and replaces the root script with one that extends
`MathEquationGame` and overrides two virtual methods, and optionally a third:

```gdscript
func _make_generator(params: Dictionary, object_ids: PackedStringArray,
		rng: RandomNumberGenerator) -> QuestionGenerator
func _operator_text() -> String                        # the sign, such as "-"
func _group_b_sprite(question: Dictionary) -> Texture2D  # optional; default: the question's object
```

`setup()` keeps the generator in a `QuestionGenerator`-typed var, and
`next_question()` calls its `generate()`, which must return
`{a, b, answer, choices, object_id, ...}`. `_choices.chosen` is connected to
`choice_made.emit` once, in `_ready()`, so a second `setup()` doesn't connect it
again. Hard levels of up to 12 and 12 objects (three rows each) fit at 16:9, 4:3 and
16:10.

### `MathPairGenerator` (`games/math_common/math_pair_generator.gd`)

The shared generator base of the `a <op> b = ?` games
(`class_name MathPairGenerator extends QuestionGenerator`). It holds:

- `_pairs`, every valid `(a, b)` pair of the level as `Vector2i`, which the
  subclass fills in its `_init()`
- the uniform pick of a pair that is never the previous one (`_pick_pair_index()`)
- the object pick from the catalog's object ids
- `generate()`, which returns `{a, b, answer, choices, object_id, key}`.
  `choices` holds `CHOICE_COUNT` (4) unique ints from the subclass's smallest
  choice up, from `QuestionUtils.number_choices()`, and `key` is `"a<sign>b"`.

Per question the RNG is drawn in this order: the pair, the object, the choices.
Keep that order, so a seed replays the same round.

A subclass calls `super(name, sign, min_choice, object_ids, rng)` first in its
`_init()`, appends its pairs to `_pairs`, and overrides `_answer(pair) -> int`.

## Step by step: the subtraction game

`math_subtraction` ("minus") is the worked example: a game on the shared equation
layout. Its files are `games/math_subtraction/subtraction_generator.gd`,
`math_subtraction.gd` and `math_subtraction.tscn`.

1. **Write the generator**, `subtraction_generator.gd`: a pure class with an
   injected RNG that extends `MathPairGenerator`. It builds every valid `(a, b)`
   pair for the level once; the base picks one uniformly per question, skipping the
   previous pair, and builds the question. Shortened:

   ```gdscript
   class_name SubtractionGenerator
   extends MathPairGenerator

   const MIN_CHOICE := 0   # 0 is a valid answer (a - a)


   func _init(params: Dictionary, object_ids: PackedStringArray, rng: RandomNumberGenerator) -> void:
   	super("SubtractionGenerator", "-", MIN_CHOICE, object_ids, rng)
   	var max_minuend := int(params["max_minuend"])   # JSON numbers may be floats
   	var min_minuend := maxi(int(params.get("min_minuend", 1)), 1)
   	for a in range(min_minuend, max_minuend + 1):
   		for b in range(1, a + 1):
   			_pairs.append(Vector2i(a, b))


   func _answer(pair: Vector2i) -> int:
   	return pair.x - pair.y
   ```

   The real file also pushes an error for a missing `max_minuend` or an empty pair
   list, and documents the params. `AdditionGenerator` has the same shape, with
   `max_sum`, `max_addend` and `min_sum`, and `MIN_CHOICE` 1.

2. **Write the view script**, `math_subtraction.gd`. The base does everything else.
   Subtraction also overrides `_group_b_sprite()`, so the b taken away show as red
   ✕ marks (the `mark_x` sprite) instead of objects:

   ```gdscript
   extends MathEquationGame
   ## Math, subtraction: `a - b = ?` on the shared equation layout.

   const MARK_SPRITE := "mark_x"


   func _make_generator(params: Dictionary, object_ids: PackedStringArray,
   		rng: RandomNumberGenerator) -> QuestionGenerator:
   	return SubtractionGenerator.new(params, object_ids, rng)


   func _operator_text() -> String:
   	return "-"


   func _group_b_sprite(_question: Dictionary) -> Texture2D:
   	return Art.sprite(MARK_SPRITE)
   ```

   `math_addition.gd` is the same without `_group_b_sprite()`. A sprite the code
   draws by id, like `mark_x`, goes in `Content.REQUIRED_SPRITES`, and not in
   `content/objects.json`, so it's never picked as a counting object.

3. **Make the scene**, `math_subtraction.tscn`: an inherited scene of the shared
   one, with the root script swapped (in the editor: Scene → New Inherited Scene):

   ```
   [gd_scene load_steps=3 format=3]

   [ext_resource type="PackedScene" path="res://games/math_common/math_equation.tscn" id="1_base"]
   [ext_resource type="Script" path="res://games/math_subtraction/math_subtraction.gd" id="2_script"]

   [node name="MathSubtraction" instance=ExtResource("1_base")]
   script = ExtResource("2_script")
   ```

   The shell's top bar (the back button, and the star bar to its right) takes the
   top 30 px, so the game gets the area below it, inset 4 px: 312×146 at 16:9.

4. **Add the catalog entry** to the mode's `games` in `content/catalog.json`. The
   order in the file is the menu order; subtraction comes after addition.

   ```json
   {
     "id": "math_subtraction", "title_key": "GAME_MATH_SUBTRACTION", "icon": "icon_subtraction",
     "scene": "res://games/math_subtraction/math_subtraction.tscn",
     "round_length": 10,
     "params": {},
     "levels": [
       {"id": "easy",   "title_key": "LEVEL_EASY",   "stars": 1, "color": "green",  "params": {"max_minuend": 5}},
       {"id": "medium", "title_key": "LEVEL_MEDIUM", "stars": 2, "color": "orange", "params": {"max_minuend": 10}},
       {"id": "hard",   "title_key": "LEVEL_HARD",   "stars": 3, "color": "red",    "params": {"min_minuend": 8, "max_minuend": 12}}
     ]
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
   | `levels` | optional; without it the mode menu opens the game directly (see below) |

5. **Add the label** to `content/locale/ui.csv`, one line per key, with a text for
   every language column:

   ```csv
   GAME_MATH_SUBTRACTION,minus
   ```

6. **Give it an icon.** Draw a 16×16 grid in `content/sprites/icons.json` (see
   [art-and-audio.md](art-and-audio.md)), or drop `assets/sprites/<id>.png`.
   `icon_subtraction` is a yellow minus bar with a black outline, which stands out
   on the red math tile.

7. **Check the glyphs.** The font covers a–z, A–Z, 0–9, `! + , - . : = ? _` and
   space. Validation checks the word packs (in both cases), the digits and signs in
   `Content.REQUIRED_GLYPHS` (`0123456789+-=?`) and the UI strings, but not other
   characters a game draws. Subtraction added `-` to `REQUIRED_GLYPHS`. Add any new
   character a game draws there, and its glyph to `content/font.json`.

8. **Run the checks:**

   ```bash
   make smoke                                          # content is valid, the scene loads, its root is a MiniGame
   godot --path . -- --open=math_subtraction:hard --seed=1
   make test
   ```

   `Content` reports catalog problems (a missing scene, a missing title key or icon)
   on startup and in `make smoke`. To check a generator over many questions, run it
   from a seeded test or a scratch probe; see
   [testing-and-export.md](testing-and-export.md).

## A game with its own layout

A game that isn't an equation extends `MiniGame` directly, as
`games/word_missing_letter/word_missing_letter.gd` does. Instance
`ui/choice_row.tscn` in its scene as a unique `%Choices`, and let the row do the
button work:

```gdscript
extends MiniGame

const CHOICE_SIZE := Vector2(40, 40)

var _generator: CountingGenerator   # your pure generator, extends QuestionGenerator
var _question: Dictionary = {}

@onready var _choices: ChoiceRow = %Choices


func _ready() -> void:
	# Once, here: the shell adds the game to the tree before it calls setup().
	_choices.chosen.connect(choice_made.emit)


func setup(params: Dictionary, rng: RandomNumberGenerator) -> void:
	_generator = CountingGenerator.new(params, rng)


func next_question() -> Dictionary:
	return _generator.generate()


func present(question: Dictionary) -> void:
	_question = question
	# ... draw the question ...
	_choices.set_choices(question["choices"], CHOICE_SIZE)


func show_wrong(value: Variant) -> void:
	await _choices.show_wrong(value)
	feedback_done.emit()


func show_correct() -> void:
	# ... fill the blank ...
	await _choices.show_correct(_question["answer"])
	feedback_done.emit()
```

The word game also passes the merged level `params` to its generator, which uses
them to choose the words and the blank (`max_length`, `blank`); see
[content-and-localization.md](content-and-localization.md#word-levels). The
catalog entry, label, icon, glyph and check steps are the same as above.

## Adding levels

Add a `levels` array to the game's catalog entry. The game then gets a level select
screen, and `--open=<game>` without a level opens the first one.

```json
"levels": [
  {"id": "easy", "title_key": "LEVEL_EASY", "stars": 1, "color": "green", "params": {"max_count": 5}},
  {"id": "hard", "title_key": "LEVEL_HARD", "stars": 3, "color": "red",   "params": {"max_count": 10}}
]
```

- `id` is unique within the game. `stars` (1–3) is how many stars the level tile
  shows. `title_key` must be in `ui.csv`; `LEVEL_EASY`, `LEVEL_MEDIUM` and
  `LEVEL_HARD` already are.
- `color` (optional) is the level tile's palette color name
  (`content/palette.json`). Every level today uses easy `green`, medium `orange`
  and hard `red`. Orange, not yellow, for medium, because the gold level stars
  vanish on yellow and the white label reads poorly on it. Without `color`, the tile
  takes the mode's color. Validation reports a color that isn't a non-empty string
  or a known palette name.
- A level's `params` are merged over the game's `params`, and the level wins.
- Level tiles are 88×90, so three fit in a row at 320 px.

## Adding a mode

Adding a mode is data only. Add an entry to `modes` in `content/catalog.json`, with
at least one game:

```json
{
  "id": "shapes", "title_key": "MODE_SHAPES", "icon": "icon_shapes", "color": "green",
  "games": [ ... ]
}
```

- `color` is a palette color name (`content/palette.json`), used for the mode's
  tiles. `icon` is a 16×16 sprite id, and `title_key` goes in `ui.csv`.
- The main menu fits any number of modes. Its tiles are 120×110 while the modes fit
  in one row at that size (two do). With more, `MenuTiles.fit_tiles()` sizes them:
  `MenuTiles.fit_grid()` picks the column count that gives the biggest tiles in the
  space under the title, and the tiles shrink and wrap into rows. When a tile's
  content wouldn't fit, every tile switches to 1× icons or the 9 px label, so they
  all match. The layout is redone when the window is resized.
- The mode menu fits any number of games the same way, with
  `MenuTiles.fit_tiles()`. Its tiles are 96×96 while the games fit in one row at
  that size (three do at 320 px); with more they shrink, wrap into rows and may be
  non-square (for example four games are 72×96 in one row at 16:9). The tiles
  always start below the back button (`BackButton.CLEAR_BOTTOM`) and end 4 px
  above the bottom edge.
