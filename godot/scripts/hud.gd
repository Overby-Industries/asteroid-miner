extends CanvasLayer
class_name HUD

const MiniMap = preload("res://scripts/ui/minimap.gd")

# Every panel shares the same screen margin, internal padding, and
# background style so the layout reads as one system rather than several
# ad-hoc boxes. Add new panels through _make_panel() to keep it that way.

const SCREEN_MARGIN := 16
const PANEL_PADDING := 16
const PANEL_BG := Color(0.05, 0.05, 0.08, 0.78)
const PANEL_RADIUS := 6

var stats_panel: PanelContainer
var controls_panel: PanelContainer
var minimap_panel: PanelContainer

var o2_bar: ProgressBar
var fuel_bar: ProgressBar
var level_label: Label
var lives_label: Label
var quota_label: Label
var cargo_label: Label
var depth_label: Label

var minimap: MiniMap

var message_label: Label
var sub_label: Label
var game_over_box: Control

var title_card_box: PanelContainer
var title_main_label: Label
var title_sub_label: Label

var upgrade_toast_box: PanelContainer
var upgrade_toast_name_label: Label
var upgrade_toast_desc_label: Label
var _upgrade_toast_tween: Tween

var fade_rect: ColorRect

func _ready() -> void:
    layer = 10
    _build_stats_panel()
    _build_controls_panel()
    _build_minimap_panel()
    _build_title_card()
    _build_upgrade_toast()
    _build_game_over_panel()
    _build_fade_overlay()

func _make_panel(custom_min: Vector2 = Vector2.ZERO) -> PanelContainer:
    var panel := PanelContainer.new()
    if custom_min != Vector2.ZERO:
        panel.custom_minimum_size = custom_min
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG
    style.set_content_margin_all(PANEL_PADDING)
    style.set_corner_radius_all(PANEL_RADIUS)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    return panel

# Anchors a panel to a screen edge/corner using its CURRENT minimum size.
# Must be called after the panel's content (children) is fully built --
# calling it earlier bakes in the near-empty pre-content size, and any
# growth from there extends away from the anchored corner. For a top-left
# panel that growth stays on screen; for a bottom/right/center anchor it
# pushes the panel past that edge and off screen. See PROJECT memory
# "project-overview" for the full writeup of this gotcha.
func _anchor_panel(panel: PanelContainer, preset: int, mode: int) -> void:
    panel.set_anchors_and_offsets_preset(preset, mode, SCREEN_MARGIN)

func _label(text: String, color := Color(1, 1, 1), size := 14) -> Label:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_color_override("font_color", color)
    lbl.add_theme_font_size_override("font_size", size)
    return lbl

func _build_stats_panel() -> void:
    stats_panel = _make_panel()
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 6)
    stats_panel.add_child(vbox)

    level_label = _label("LEVEL 1 -- Ashfall Rubble", Color(0.75, 0.85, 1.0), 15)
    vbox.add_child(level_label)

    lives_label = _label("LIVES 3", Color(1.0, 0.75, 0.75))
    vbox.add_child(lives_label)

    quota_label = _label("Fuel ore banked 0 / 6", Color(0.6, 0.95, 0.75))
    vbox.add_child(quota_label)

    vbox.add_child(HSeparator.new())

    o2_bar = _make_stat_row(vbox, "O2", Color(0.3, 0.75, 1.0))
    fuel_bar = _make_stat_row(vbox, "FUEL", Color(1.0, 0.7, 0.2))

    cargo_label = _label("CARGO   0 gold  0 nickel  0 fuel ore")
    vbox.add_child(cargo_label)

    depth_label = _label("DEPTH   0m      BANKED  0 cr")
    vbox.add_child(depth_label)

    _anchor_panel(stats_panel, Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)

func _make_stat_row(parent: VBoxContainer, label_text: String, color: Color) -> ProgressBar:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)

    var lbl := _label(label_text)
    lbl.custom_minimum_size = Vector2(46, 0)
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

func _build_controls_panel() -> void:
    controls_panel = _make_panel()
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 3)
    controls_panel.add_child(vbox)

    vbox.add_child(_label("CONTROLS", Color(1, 1, 1, 0.6), 12))
    var lines := [
        "A / D -- move",
        "W / Space -- thrust up",
        "S -- thrust down",
        "Hold Left Click -- dig (push toward rock)",
        "R -- try again (after a run ends)",
        "ESC -- pause",
    ]
    for line in lines:
        vbox.add_child(_label(line, Color(1, 1, 1, 0.75), 13))

    _anchor_panel(controls_panel, Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)

func _build_minimap_panel() -> void:
    minimap_panel = _make_panel(Vector2(120, 0))
    minimap = MiniMap.new()
    minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
    minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    minimap_panel.add_child(minimap)

    _anchor_panel(minimap_panel, Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_KEEP_WIDTH)

func _build_title_card() -> void:
    title_card_box = _make_panel()
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    title_card_box.add_child(vbox)

    title_main_label = _label("", Color(0.75, 0.85, 1.0), 26)
    title_main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_main_label)

    title_sub_label = _label("", Color(1, 1, 1, 0.8), 15)
    title_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_sub_label)

    var skip_hint := _label("Press ENTER to skip", Color(1, 1, 1, 0.5), 12)
    skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(skip_hint)

    _anchor_panel(title_card_box, Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
    title_card_box.visible = false

# Separate panel from title_card_box on purpose -- a score-threshold
# upgrade grant can fire while a level-transition title card is showing
# (both are triggered from cargo-banking/level-advance in main.gd), and
# sharing one node would mean the two fight over its visibility/timing.
func _build_upgrade_toast() -> void:
    upgrade_toast_box = _make_panel()
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    upgrade_toast_box.add_child(vbox)

    var header := _label("UPGRADE UNLOCKED", Color(0.6, 0.95, 0.75), 13)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(header)

    upgrade_toast_name_label = _label("", Color(1, 1, 1), 20)
    upgrade_toast_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(upgrade_toast_name_label)

    upgrade_toast_desc_label = _label("", Color(1, 1, 1, 0.75), 13)
    upgrade_toast_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(upgrade_toast_desc_label)

    _anchor_panel(upgrade_toast_box, Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
    upgrade_toast_box.visible = false

func show_upgrade_toast(name: String, desc: String = "") -> void:
    upgrade_toast_name_label.text = name
    upgrade_toast_desc_label.text = desc
    upgrade_toast_box.visible = true
    upgrade_toast_box.modulate.a = 1.0
    if _upgrade_toast_tween and _upgrade_toast_tween.is_valid():
        _upgrade_toast_tween.kill()
    _upgrade_toast_tween = create_tween()
    _upgrade_toast_tween.tween_interval(2.2)
    _upgrade_toast_tween.tween_property(upgrade_toast_box, "modulate:a", 0.0, 0.5)
    _upgrade_toast_tween.tween_callback(func(): upgrade_toast_box.visible = false)

func hide_upgrade_toast() -> void:
    if _upgrade_toast_tween and _upgrade_toast_tween.is_valid():
        _upgrade_toast_tween.kill()
    upgrade_toast_box.visible = false

func _build_game_over_panel() -> void:
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(center)

    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.05, 0.07, 0.88)
    style.set_content_margin_all(PANEL_PADDING * 2)
    style.set_corner_radius_all(PANEL_RADIUS)
    panel.add_theme_stylebox_override("panel", style)
    center.add_child(panel)

    var panel_vbox := VBoxContainer.new()
    panel_vbox.add_theme_constant_override("separation", 8)
    panel.add_child(panel_vbox)

    message_label = _label("RUN OVER", Color(1, 0.4, 0.35), 32)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel_vbox.add_child(message_label)

    sub_label = _label("", Color(1, 1, 1), 14)
    sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel_vbox.add_child(sub_label)

    game_over_box = center
    game_over_box.visible = false

func _build_fade_overlay() -> void:
    fade_rect = ColorRect.new()
    fade_rect.color = Color(0, 0, 0, 0)
    fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fade_rect)

func set_gameplay_panels_visible(v: bool) -> void:
    stats_panel.visible = v
    controls_panel.visible = v
    minimap_panel.visible = v

func update_stats(
    o2: float, fuel: float, lives: int,
    cargo_gold: int, cargo_nickel: int, cargo_fuel_ore: int, cargo_credit: int,
    banked_score: int, depth_m: int,
    level_name: String, level_number: int,
    fuel_ore_banked: int, fuel_ore_quota: int
) -> void:
    o2_bar.value = o2
    fuel_bar.value = fuel
    level_label.text = "LEVEL %d -- %s" % [level_number, level_name]
    lives_label.text = "LIVES %d" % lives
    quota_label.text = "Fuel ore banked %d / %d" % [fuel_ore_banked, fuel_ore_quota]
    cargo_label.text = "CARGO   %d gold  %d nickel  %d fuel ore  (%d cr held)" % [cargo_gold, cargo_nickel, cargo_fuel_ore, cargo_credit]
    depth_label.text = "DEPTH   %dm      BANKED  %d cr" % [depth_m, banked_score]

func update_minimap(progress: float, depth_m: int, max_depth_m: int, fuel_ore_banked: int, fuel_ore_quota: int) -> void:
    minimap.set_progress(progress, "%dm / %dm" % [depth_m, max_depth_m], "Fuel ore %d/%d" % [fuel_ore_banked, fuel_ore_quota])

func show_game_over(reason: String, score: int, depth_m: int, lives_remaining: int) -> void:
    message_label.text = "RUN OVER"
    message_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
    var lives_word := "life" if lives_remaining == 1 else "lives"
    sub_label.text = "%s\n\nBanked %d credits this level   |   reached %dm deep\n\n%d %s remaining\n\nPress R to try again" % [reason, score, depth_m, lives_remaining, lives_word]
    game_over_box.visible = true

func hide_game_over() -> void:
    game_over_box.visible = false

func show_title_card(main_text: String, sub_text: String) -> void:
    title_main_label.text = main_text
    title_sub_label.text = sub_text
    title_card_box.modulate.a = 1.0
    title_card_box.visible = true

func hide_title_card() -> void:
    title_card_box.visible = false

func fade_to_black(duration: float) -> void:
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, duration)
    await tween.finished

func fade_from_black(duration: float) -> void:
    var tween := create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, duration)
    await tween.finished
