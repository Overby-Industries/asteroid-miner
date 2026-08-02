extends Control
class_name MiniMap

# Vertical depth strip: this game is a single shaft, not open terrain, so a
# top-down map isn't meaningful. Shows the mothership fixed at the top, the
# rig's current position along the shaft, and a numeric depth readout.

const TOP_PAD := 40.0
const BOTTOM_PAD := 40.0
const SHIP_COLOR := Color(0.55, 0.75, 1.0)
const PLAYER_COLOR := Color(1.0, 0.85, 0.3)
const TRACK_COLOR := Color(1, 1, 1, 0.3)

var progress := 0.0
var depth_text := "0m"
var quota_text := ""

func set_progress(p: float, depth_label: String, quota_label: String = "") -> void:
    progress = clamp(p, 0.0, 1.0)
    depth_text = depth_label
    quota_text = quota_label
    queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    var track_x := w * 0.5
    var top_y := TOP_PAD
    var bottom_y := h - BOTTOM_PAD
    if bottom_y <= top_y:
        return

    var font := ThemeDB.fallback_font

    draw_line(Vector2(track_x, top_y), Vector2(track_x, bottom_y), TRACK_COLOR, 3.0)

    draw_circle(Vector2(track_x, top_y), 7.0, SHIP_COLOR)
    draw_string(font, Vector2(4, top_y - 16), "SHIP", HORIZONTAL_ALIGNMENT_CENTER, w - 8, 12, SHIP_COLOR)

    var player_y: float = lerp(top_y, bottom_y, progress)
    draw_circle(Vector2(track_x, player_y), 6.0, PLAYER_COLOR)

    draw_string(font, Vector2(4, bottom_y + 20), depth_text, HORIZONTAL_ALIGNMENT_CENTER, w - 8, 13, Color(1, 1, 1, 0.9))
    if quota_text != "":
        draw_string(font, Vector2(4, bottom_y + 36), quota_text, HORIZONTAL_ALIGNMENT_CENTER, w - 8, 12, Color(0.6, 0.95, 0.75))
