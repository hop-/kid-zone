class_name BackButton
extends IconButton
## The back button of every screen but the main menu. It calls `Router.back()` on
## release, which plays the `back` sound, so it plays no `tap`.
##
## It places itself in `_ready()`: at the top, with its left edge at `EDGE_FRACTION`
## of the screen width (x 64 at 320 px wide, further right on wider screens), away
## from the left edge where a kid's thumb rests. `EDGE_FRACTION` is the one place
## this position is set; a screen that has something else at the top moves it out
## of the button's way with `keep_clear()` or below `CLEAR_BOTTOM`.

## The button's left edge, as a fraction of its parent's width.
const EDGE_FRACTION := 0.2
## The button's distance from the top, in virtual pixels.
const TOP_MARGIN := 4.0
## The gap between the button's drawn right edge and a control beside it; it is
## bigger than the touch margin, so the button's touch area stays clear too.
const SIDE_GAP := 8.0
## The y where a control under the button may start, `SIDE_GAP` below its drawn
## bottom edge (and below its touch area).
const CLEAR_BOTTOM := TOP_MARGIN + BUTTON_SIZE.y + SIDE_GAP


func _init() -> void:
	super()
	icon_id = "icon_back"
	press_sfx = ""
	pressed.connect(_on_pressed)


func _ready() -> void:
	super()
	anchor_left = EDGE_FRACTION
	anchor_right = EDGE_FRACTION
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = TOP_MARGIN
	offset_right = BUTTON_SIZE.x
	offset_bottom = TOP_MARGIN + BUTTON_SIZE.y


## Starts `control` (a child of the same parent as the button) just right of the
## back button, `SIDE_GAP` past its drawn edge, keeping its other anchors and offsets.
static func keep_clear(control: Control) -> void:
	control.anchor_left = EDGE_FRACTION
	control.offset_left = BUTTON_SIZE.x + SIDE_GAP


func _on_pressed() -> void:
	Router.back()
