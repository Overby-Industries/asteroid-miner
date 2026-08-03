extends CanvasLayer
class_name MainMenu

# Purely visual -- main.gd owns all input routing (see its
# _unhandled_key_input) and just toggles this node's visibility based on
# game state, so there's a single place that decides what a keypress means.

var prompt_label: Label

func _ready() -> void:
    layer = 20

    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.03, 0.06, 1.0)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(center)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "ASTEROID MINER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    vbox.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Dig deep. Bank what you find. Get back before you run out."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
    vbox.add_child(subtitle)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 10)
    vbox.add_child(spacer)

    prompt_label = Label.new()
    prompt_label.text = "Press SPACE to launch"
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.add_theme_font_size_override("font_size", 18)
    prompt_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.75))
    vbox.add_child(prompt_label)

    var pulse := create_tween()
    pulse.set_loops()
    pulse.tween_property(prompt_label, "modulate:a", 0.35, 0.8)
    pulse.tween_property(prompt_label, "modulate:a", 1.0, 0.8)
