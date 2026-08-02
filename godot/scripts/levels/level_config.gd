extends RefCounted
class_name LevelConfig

# Per-level identity: color palette, hazard escalation, and the fuel-ore
# quota that must be banked (across as many dives as it takes) before the
# next, harder asteroid generates. Levels 0-2 are hand-authored; anything
# beyond falls back to a formula so progression never hard-stops.

var index: int
var level_name: String
var rock_color: Color
var cracked_color: Color
var bedrock_color: Color
var gold_color: Color
var nickel_color: Color
var fuel_ore_color: Color
var heat_color: Color
var hazard_density: float
var fuel_ore_quota: int
var noise_frequency: float

static func for_level(index: int):
    var cfg = load("res://scripts/levels/level_config.gd").new()
    cfg.index = index
    match index:
        0:
            cfg.level_name = "Ashfall Rubble"
            cfg.rock_color = Color(0.34, 0.32, 0.32)
            cfg.hazard_density = 1.0
            cfg.fuel_ore_quota = 6
            cfg.noise_frequency = 0.07
        1:
            cfg.level_name = "Rustvein Shard"
            cfg.rock_color = Color(0.44, 0.26, 0.2)
            cfg.hazard_density = 1.35
            cfg.fuel_ore_quota = 9
            cfg.noise_frequency = 0.08
        2:
            cfg.level_name = "Glacient Core"
            cfg.rock_color = Color(0.24, 0.28, 0.36)
            cfg.hazard_density = 1.7
            cfg.fuel_ore_quota = 12
            cfg.noise_frequency = 0.09
        _:
            var t := float(index - 2)
            cfg.level_name = "Deep Claim %d" % (index + 1)
            cfg.rock_color = Color(0.3, 0.3, 0.32).lerp(Color(0.14, 0.1, 0.12), min(1.0, t * 0.12))
            cfg.hazard_density = 1.7 + t * 0.25
            cfg.fuel_ore_quota = 12 + int(t * 4.0)
            cfg.noise_frequency = 0.09

    # Mineral/hazard colors stay consistent across levels so players can
    # always read them at a glance -- only the surrounding regolith and
    # difficulty shift per level.
    cfg.cracked_color = Color(0.56, 0.36, 0.2)
    cfg.bedrock_color = Color(0.16, 0.16, 0.18)
    cfg.gold_color = Color(0.86, 0.69, 0.16)
    cfg.nickel_color = Color(0.68, 0.74, 0.78)
    cfg.fuel_ore_color = Color(0.22, 0.86, 0.62)
    cfg.heat_color = Color(0.86, 0.26, 0.1)
    return cfg
