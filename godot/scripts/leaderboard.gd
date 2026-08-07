extends Node

# Autoloaded as "Leaderboard". Local top-10 high score list, persisted as
# JSON at user:// (resolves to
# %APPDATA%\Godot\app_userdata\Asteroid Miner\leaderboard.json on Windows,
# from [application] config/name in project.godot -- no manual path
# handling needed on any platform).

const SAVE_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 10

var _entries: Array = []

func _ready() -> void:
    _load()

func qualifies(score: int) -> bool:
    return _entries.size() < MAX_ENTRIES or score > _entries[-1].score

func submit(player_name: String, score: int, level_reached: int) -> void:
    var clean_name := player_name.strip_edges()
    if clean_name.length() > 20:
        clean_name = clean_name.substr(0, 20)
    if clean_name == "":
        clean_name = "ANONYMOUS"
    _entries.append({
        "name": clean_name,
        "score": score,
        "level_reached": level_reached,
        "date": Time.get_date_string_from_system(),
    })
    _entries.sort_custom(func(a, b): return a.score > b.score)
    if _entries.size() > MAX_ENTRIES:
        _entries.resize(MAX_ENTRIES)
    _save()

func get_entries() -> Array:
    return _entries.duplicate(true)

func _load() -> void:
    _entries = []
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Array:
        for item in parsed:
            if item is Dictionary and item.has("name") and item.has("score"):
                # JSON.parse_string() returns all numbers as float, never
                # int -- explicit coercion here is load-bearing, not
                # decoration, or qualifies()'s score comparison and %d
                # formatting downstream silently operate on the wrong type.
                _entries.append({
                    "name": str(item.get("name", "ANONYMOUS")),
                    "score": int(item.get("score", 0)),
                    "level_reached": int(item.get("level_reached", 1)),
                    "date": str(item.get("date", "")),
                })
    _entries.sort_custom(func(a, b): return a.score > b.score)

func _save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        push_warning("Leaderboard: failed to open %s for writing" % SAVE_PATH)
        return
    f.store_string(JSON.stringify(_entries, "  "))
    f.close()
