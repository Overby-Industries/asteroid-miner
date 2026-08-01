extends CanvasLayer
class_name HUD

var o2_bar: ProgressBar
var fuel_bar: ProgressBar
var cargo_label: Label
var depth_label: Label
var message_label: Label
var sub_label: Label
var game_over_box: Control

func _ready() -> void:
    layer = 10

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 16)
    add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    margin.add_child(vbox)

    o2_bar = _make_stat_row(vbox, "O2", Color(0.3, 0.75, 1.0))
    fuel_bar = _make_stat_row(vbox, "FUEL", Color(1.0, 0.7, 0.2))

    cargo_label = Label.new()
    cargo_label.add_theme_color_override("font_color", Color(1, 1, 1))
    vbox.add_child(cargo_label)

    depth_label = Label.new()
    depth_label.add_theme_color_override("font_color", Color(1, 1, 1))
    vbox.add_child(depth_label)

    var hint := Label.new()
    hint.text = "A/D move   W thrust up   S thrust down   push into rock to dig"
    hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
    hint.add_theme_font_size_override("font_size", 13)
    vbox.add_child(hint)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(center)

    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.05, 0.07, 0.85)
    style.set_content_margin_all(24)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var panel_vbox := VBoxContainer.new()
    panel_vbox.add_theme_constant_override("separation", 8)
    panel.add_child(panel_vbox)

    message_label = Label.new()
    message_label.add_theme_font_size_override("font_size", 32)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
    panel_vbox.add_child(message_label)

    sub_label = Label.new()
    sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_label.add_theme_color_override("font_color", Color(1, 1, 1))
    panel_vbox.add_child(sub_label)

    game_over_box = center
    game_over_box.visible = false

func _make_stat_row(parent: VBoxContainer, label_text: String, color: Color) -> ProgressBar:
    var row := HBoxContainer.new()
    var lbl := Label.new()
    lbl.text = label_text
    lbl.custom_minimum_size = Vector2(50, 0)
    lbl.add_theme_color_override("font_color", Color(1, 1, 1))
    row.add_child(lbl)

    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(200, 18)
    bar.min_value = 0
    bar.max_value = 100
    bar.value = 100
    bar.show_percentage = false
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    bar.add_theme_stylebox_override("fill", fill)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0, 0, 0, 0.4)
    bar.add_theme_stylebox_override("background", bg)
    row.add_child(bar)

    parent.add_child(row)
    return bar

func update_stats(o2: float, fuel: float, cargo_count: int, cargo_value: int, depth_m: int, score: int) -> void:
    o2_bar.value = o2
    fuel_bar.value = fuel
    cargo_label.text = "CARGO   %d ore  (%d cr held)" % [cargo_count, cargo_value]
    depth_label.text = "DEPTH   %dm      BANKED  %d cr" % [depth_m, score]

func show_game_over(reason: String, score: int, depth_m: int) -> void:
    message_label.text = "RUN OVER"
    sub_label.text = "%s\n\nBanked %d credits   ·   reached %dm deep\n\nPress R to descend again" % [reason, score, depth_m]
    game_over_box.visible = true

func hide_game_over() -> void:
    game_over_box.visible = false
