# Design notes (early)

Captured from the initial pitch -- expand as the design firms up.

- **View**: 2D, side-on, digging into a single asteroid body (not a
  free-floating space scene) -- closer to a classic dig-and-haul miner
  than to Aevoria Simulator's 3D tables.
- **Core loop**: descend/tunnel through procedurally generated
  rock/ore layers, manage limited resources (O2, fuel, cargo capacity),
  and return to the surface before you run out. Risk/reward comes from
  how far you push before turning back.
- **Procedural generation**: rock layer composition, ore placement,
  and tunnel-wall texturing should reuse Aevoria Simulator's
  `ProceduralArtGenerator` texture-recipe approach (seed + frequency +
  dark/base/highlight colors) rather than a new system -- same visual
  language, proven code.
- **Scope discipline**: this is deliberately a small, shippable title,
  not a second Aevoria. Resist scope creep toward multiple biomes,
  factions, or progression systems unless the core loop is already fun
  and finished.
- **Relationship to Aevoria Simulator**: standalone game, not a DLC or
  required companion -- but sharing engine conventions (Godot 4 + C++
  GDExtension split) and possibly some procedural-generation code
  keeps studio tooling reusable across both titles.
