extends CanvasLayer
class_name PauseMenu

# Owns all ESC pause/resume handling and the exit button. process_mode is
# ALWAYS so this keeps receiving input while SceneTree.paused freezes
# everything else -- main.gd just tells us when pausing is allowed (see
# `enabled`) as it moves through its MENU/CUTSCENE/PLAYING state machine.

const PANEL_BG := Color(0.05, 0.05, 0.08, 0.9)
const PANEL_PADDING := 20
const PANEL_RADIUS := 6
const SCREEN_MARGIN := 16

var enabled := false

var dim_rect: ColorRect
var exit_button: Button

func _ready() -> void:
    layer = 15
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false

    dim_rect = ColorRect.new()
    dim_rect.color = Color(0, 0, 0, 0.55)
    dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim_rect)

    _build_title_panel()
    _build_exit_button()

func _build_title_panel() -> void:
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
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "PAUSED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    vbox.add_child(title)

    var hint := Label.new()
    hint.text = "Press ESC to resume"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 14)
    hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
    vbox.add_child(hint)

func _build_exit_button() -> void:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG
    style.set_content_margin_all(PANEL_PADDING * 0.5)
    style.set_corner_radius_all(PANEL_RADIUS)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    exit_button = Button.new()
    exit_button.text = "EXIT GAME"
    exit_button.add_theme_font_size_override("font_size", 16)
    exit_button.custom_minimum_size = Vector2(140, 40)
    exit_button.pressed.connect(_on_exit_pressed)
    panel.add_child(exit_button)

    # Anchored after the button is added so the MINSIZE offset math uses
    # the panel's real size -- see hud.gd's _anchor_panel for why order
    # matters here.
    panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, SCREEN_MARGIN)

func set_enabled(v: bool) -> void:
    enabled = v
    if not enabled:
        resume()

func pause() -> void:
    visible = true
    get_tree().paused = true

func resume() -> void:
    visible = false
    get_tree().paused = false

func _on_exit_pressed() -> void:
    get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode != KEY_ESCAPE:
        return
    if visible:
        resume()
    elif enabled:
        pause()
