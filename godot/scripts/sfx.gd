extends Node

# Autoloaded as "Sfx". Every sound the game plays is synthesized once here
# at startup by the SfxGenerator GDExtension class (src/sfx_generator.cpp)
# and cached -- there are no .wav assets on disk. Call Sfx.play(name) for a
# non-positional cue or Sfx.play_at(name, world_pos) for one that should
# come from a specific point in the world; for a sound a script wants to
# start/stop itself (looping thruster hum, heat-vent hiss), grab the raw
# stream with Sfx.stream(name) and drive an AudioStreamPlayer2D directly.

const MAX_ONE_SHOT_VOICES := 8

var _streams: Dictionary = {}
var _one_shot_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
    _streams["dig_hit"] = SfxGenerator.dig_hit()
    _streams["ore_pickup_gold"] = SfxGenerator.ore_pickup(0)
    _streams["ore_pickup_nickel"] = SfxGenerator.ore_pickup(1)
    _streams["ore_pickup_fuel"] = SfxGenerator.ore_pickup(2)
    _streams["thruster_loop"] = SfxGenerator.thruster_loop()
    _streams["low_resource_alarm"] = SfxGenerator.low_resource_alarm()
    _streams["cave_in_rumble"] = SfxGenerator.cave_in_rumble()
    _streams["heat_vent_hiss"] = SfxGenerator.heat_vent_hiss()
    _streams["vent_blast"] = SfxGenerator.vent_blast()
    _streams["dock_chime"] = SfxGenerator.dock_chime()
    _streams["death_buzz"] = SfxGenerator.death_buzz()
    _streams["level_complete_sweep"] = SfxGenerator.level_complete_sweep()
    _streams["menu_blip"] = SfxGenerator.menu_blip()
    _streams["mothership_thump"] = SfxGenerator.mothership_thump()

    for i in range(MAX_ONE_SHOT_VOICES):
        var p := AudioStreamPlayer.new()
        add_child(p)
        _one_shot_pool.append(p)

func stream(name: String) -> AudioStream:
    return _streams.get(name)

func play(name: String, volume_db: float = 0.0) -> void:
    var s: AudioStream = _streams.get(name)
    if s == null:
        return
    var p := _acquire_player()
    p.stream = s
    p.volume_db = volume_db
    p.play()

func play_at(name: String, world_pos: Vector2, volume_db: float = 0.0) -> void:
    var s: AudioStream = _streams.get(name)
    if s == null:
        return
    var p := AudioStreamPlayer2D.new()
    p.stream = s
    p.volume_db = volume_db
    p.global_position = world_pos
    p.max_distance = 1400.0
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

func _acquire_player() -> AudioStreamPlayer:
    for p in _one_shot_pool:
        if not p.playing:
            return p
    # Every pooled voice is busy -- steal the first rather than growing the
    # pool. SFX are short, so an occasional stolen overlap is inaudible.
    return _one_shot_pool[0]
