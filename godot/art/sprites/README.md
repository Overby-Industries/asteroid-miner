# Pre-rendered sprite pipeline

Objects in this game are drawn procedurally in GDScript (`Polygon2D` shapes)
today. To upgrade one to a Blender-modeled look, render it out of Blender as
a transparent PNG and drop it in this folder under the path the object's
script already checks for. The script picks it up automatically on the next
run — no code changes needed. If the file isn't present, the object keeps
drawing its current procedural shape, so there's no broken/half-migrated
state at any point.

## Render setup

- **Format**: PNG, transparent background (World > Film > Transparent in
  Blender's render settings).
- **Engine**: Cycles or Eevee, either is fine -- this is a still render, not
  realtime.
- **Resolution**: doesn't need to match final on-screen size. Render big
  (e.g. 1024px on the long edge) for quality; the game scales the image
  down to the object's gameplay size automatically (see `HULL_SPRITE_SIZE`
  in each script). What matters is **canvas aspect ratio** -- match the
  "target box" aspect ratio listed per object below, padding the shorter
  side with transparent space if your model doesn't fill it, or the image
  will stretch when the game scales it to fit.
- **Camera angle -- read this before modeling**: it depends on whether the
  object rotates at runtime.
  - The **player ship rotates freely in 2D** to face travel direction
    (`rotation = facing_angle` in `player.gd`) -- Godot just spins the flat
    image in-plane, it does not re-render the model from a new angle. So
    the ship must be shot from **straight-on/orthographic, top-down**
    (camera looking straight down the axis the ship spins around), the way
    a classic top-down Asteroids-style ship sprite is drawn. A 3/4 or
    perspective angle will look wrong the moment it rotates past ~90
    degrees.
  - Objects that **never rotate at runtime** (mothership, hazards, terrain
    props -- anything only moved/scaled by a Tween, not `rotation`) can use
    whatever fixed camera angle looks best, including a nicer 3/4 view.

## Per-object reference

| Object | Sprite path | Target box (world units = px at 1x) | Rotates at runtime? |
|---|---|---|---|
| Player ship hull | `res://art/sprites/player_ship.png` | 26 x 20 | Yes -- top-down/orthographic only |
| Mothership hull | `res://art/sprites/mothership.png` | 100 x 58 | No -- any angle |

World units line up with the terrain grid: `Constants.CELL_SIZE = 32px`, so
1 world unit = 1px at the game's native (non-zoomed) scale. The gameplay
camera runs at 2x zoom, so render with enough resolution to hold up there.

Model the subject centered on the origin, nose/front pointing **+X**
(rightward) in the render, since that's the ship's forward axis in-game.

## What stays procedural

Dynamic effects (thruster flame, drill-tip glow, cockpit window glow) stay
as `Polygon2D` overlays layered on top of the sprite rather than being baked
into the render -- they're driven by game state (thrust on/off, digging
active) every frame, which a static image can't do. Only the static hull
geometry gets replaced. See the `if ResourceLoader.exists(...)` block in
`player.gd` / `mothership.gd` for exactly what swaps out.

## Adding a new object to this pipeline

1. Pick a target box size in world units (match the collision shape / the
   current `Polygon2D` extents in the script).
2. Add `const HULL_SPRITE_PATH` and `const HULL_SPRITE_SIZE` to that
   object's script, pointed at a new path in this folder.
3. Wrap the object's static-shape `Polygon2D` construction in
   `if ResourceLoader.exists(HULL_SPRITE_PATH): ... else: ...`, same
   pattern as `player.gd`.
4. Render and drop the PNG in. Done -- no further code changes.
