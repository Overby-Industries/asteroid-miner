extends CanvasLayer
class_name LeaderboardScreen

# Owns the "run ended, out of lives" leaderboard flow AND the standing
# view-only leaderboard reachable from the main menu. Architected like
# pause_menu.gd: a self-contained always-instantiated overlay with its own
# input handling and process_mode ALWAYS. Unlike PauseMenu, this doesn't
# pause the tree itself -- main.gd is responsible for having already ended
# the run (see main.gd's _on_player_died) before show_after_run() is called.

signal closed

const PANEL_BG := Color(0.05, 0.05, 0.08, 0.92)
const PANEL_PADDING := 20
const PANEL_RADIUS := 6

var dim_rect: ColorRect
var mode_label: Label
var run_summary_label: Label
var entry_list_vbox: VBoxContainer
var name_entry_row: Control
var name_entry: LineEdit
var submit_hint: Label
var continue_hint: Label

var _awaiting_name := false
var _pending_score := 0
var _pending_level := 0

func _ready() -> void:
    layer = 25
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false

    dim_rect = ColorRect.new()
    dim_rect.color = Color(0, 0, 0, 0.7)
    dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim_rect)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(center)

    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG
    style.set_content_margin_all(PANEL_PADDING)
    style.set_corner_radius_all(PANEL_RADIUS)
    panel.add_theme_stylebox_override("panel", style)
    panel.custom_minimum_size = Vector2(320, 0)
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 6)
    panel.add_child(vbox)

    mode_label = _row_label("LEADERBOARD", Color(0.85, 0.9, 1.0), 24)
    vbox.add_child(mode_label)

    run_summary_label = _row_label("", Color(1, 1, 1, 0.8), 13)
    run_summary_label.visible = false
    vbox.add_child(run_summary_label)

    vbox.add_child(HSeparator.new())

    entry_list_vbox = VBoxContainer.new()
    entry_list_vbox.add_theme_constant_override("separation", 2)
    vbox.add_child(entry_list_vbox)

    vbox.add_child(HSeparator.new())

    name_entry_row = HBoxContainer.new()
    name_entry_row.add_theme_constant_override("separation", 8)
    vbox.add_child(name_entry_row)

    var name_prompt := Label.new()
    name_prompt.text = "NAME"
    name_prompt.add_theme_font_size_override("font_size", 13)
    name_prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
    name_entry_row.add_child(name_prompt)

    name_entry = LineEdit.new()
    name_entry.max_length = 20
    name_entry.placeholder_text = "ANONYMOUS"
    name_entry.custom_minimum_size = Vector2(180, 0)
    name_entry.text_submitted.connect(_on_name_submitted)
    name_entry_row.add_child(name_entry)

    submit_hint = _row_label("Press ENTER to submit", Color(0.6, 0.95, 0.75), 12)
    vbox.add_child(submit_hint)

    continue_hint = _row_label("Press ENTER or ESC to continue", Color(1, 1, 1, 0.5), 12)
    vbox.add_child(continue_hint)

func _row_label(text: String, color := Color(1, 1, 1), size := 14) -> Label:
    var lbl := Label.new()
    lbl.text = text
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_color_override("font_color", color)
    lbl.add_theme_font_size_override("font_size", size)
    return lbl

func show_after_run(reason: String, score: int, depth_m: int, level_reached: int) -> void:
    _pending_score = score
    _pending_level = level_reached
    _awaiting_name = Leaderboard.qualifies(score)
    _refresh_entries()

    mode_label.text = "NEW HIGH SCORE!" if _awaiting_name else "RUN OVER"
    run_summary_label.text = "%s\n%d credits  |  reached level %d" % [reason, score, level_reached]
    run_summary_label.visible = true

    name_entry_row.visible = _awaiting_name
    submit_hint.visible = _awaiting_name
    continue_hint.text = "Press ENTER to submit" if _awaiting_name else "Press ENTER or ESC to continue"

    visible = true
    if _awaiting_name:
        name_entry.text = ""
        name_entry.grab_focus()

func show_view_only() -> void:
    _awaiting_name = false
    _refresh_entries()

    mode_label.text = "LEADERBOARD"
    run_summary_label.visible = false
    name_entry_row.visible = false
    submit_hint.visible = false
    continue_hint.text = "Press ENTER or ESC to close"

    visible = true

func _refresh_entries() -> void:
    for c in entry_list_vbox.get_children():
        c.queue_free()
    var entries := Leaderboard.get_entries()
    if entries.is_empty():
        entry_list_vbox.add_child(_row_label("No entries yet -- be the first.", Color(1, 1, 1, 0.6), 13))
        return
    for i in range(entries.size()):
        var e: Dictionary = entries[i]
        var row := "%2d. %-16s %6d cr  Lv %d" % [i + 1, e.name, e.score, e.level_reached]
        entry_list_vbox.add_child(_row_label(row, Color(1, 1, 1, 0.85), 13))

func _on_name_submitted(text: String) -> void:
    if not _awaiting_name:
        return
    var clean := text.strip_edges()
    Leaderboard.submit(clean if clean != "" else "ANONYMOUS", _pending_score, _pending_level)
    _awaiting_name = false
    _refresh_entries()
    name_entry_row.visible = false
    submit_hint.visible = false
    mode_label.text = "RUN OVER"
    continue_hint.text = "Press ENTER or ESC to continue"

func _close() -> void:
    visible = false
    closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    var key_event := event as InputEventKey
    if key_event.keycode == KEY_ESCAPE:
        _close()
        get_viewport().set_input_as_handled()
    elif (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER) and not _awaiting_name:
        _close()
        get_viewport().set_input_as_handled()
