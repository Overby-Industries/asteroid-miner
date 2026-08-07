extends RefCounted
class_name Upgrades

const PlayerRig = preload("res://scripts/player.gd")

# Never instantiated -- referenced via its class_name directly
# (Upgrades.DEFS, Upgrades.apply(...)), same pattern as constants.gd.
#
# Ordered progression track. main.gd owns ONE pointer (upgrade_index) that
# advances on either a level-up or a score-threshold crossing -- see
# main.gd's _grant_next_upgrade_silent(). SCORE_THRESHOLDS[i] is "the score
# needed to unlock DEFS[i]"; the two arrays are indexed in lockstep by the
# same pointer so there's exactly one source of truth for "how many
# upgrades has this run earned," never two systems racing. Capped at
# DEFS.size() rather than looped/repeated -- LevelConfig's procedural
# branch already grows hazard_density/fuel_ore_quota unbounded past level
# 2, so player power plateauing while difficulty keeps climbing is the
# existing difficulty curve doing its job, not a gap.

const SCORE_THRESHOLDS: Array[int] = [300, 600, 900, 1200, 1500, 1800]

const DEFS := [
    {"id": "wall_grip", "name": "Wall Grip", "desc": "Grip terrain on contact -- no fuel burn holding position to dig."},
    {"id": "fuel_tank", "name": "Fuel Tank+", "desc": "+40 max fuel."},
    {"id": "o2_tank", "name": "O2 Tank+", "desc": "+40 max oxygen."},
    {"id": "drill_speed", "name": "Drill Speed+", "desc": "Digs 25% faster."},
    {"id": "thruster_efficiency", "name": "Thruster Efficiency+", "desc": "Thrusters burn 25% less fuel."},
    {"id": "afterburner", "name": "Afterburner", "desc": "+20% max speed and acceleration."},
]

static func apply(id: String, player: PlayerRig) -> void:
    match id:
        "wall_grip":
            player.can_wall_grip = true
        "fuel_tank":
            player.fuel_max += 40.0
        "o2_tank":
            player.o2_max += 40.0
        "drill_speed":
            player.dig_rate *= 1.25
        "thruster_efficiency":
            player.fuel_thrust_drain *= 0.75
        "afterburner":
            player.max_speed *= 1.2
            player.thrust_accel *= 1.2
            player.side_accel *= 1.2
            player.down_thrust_accel *= 1.2
