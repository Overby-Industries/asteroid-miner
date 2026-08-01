# Asteroid Miner (working title)

A small 2D asteroid-mining game -- dig into a procedurally generated
asteroid, tunnel for ore, manage O2/fuel, and haul your finds back to a
drop-off. Built as a compact, shippable side project alongside
[Aevoria Simulator](../aevoria-simulator), Overby Industries' larger
long-term game, using the same core stack: Godot 4 + a C++ GDExtension
for anything procedural or performance-sensitive, with the game logic
itself in GDScript.

This is one of two small titles meant to help establish the studio
(the other is [Project Helga](../helga-flight-sim), a flight sim) --
scoped intentionally small so it can actually ship, rather than growing
into another Aevoria-sized project.

## Concept

Side-view digging on a single asteroid (not open space), in the spirit
of a classic dig-and-haul miner: pick a direction, dig through
procedurally generated rock/ore layers, watch your resources (O2,
fuel, cargo weight), and get back to the surface/ship before you run
out. Procedural rock textures and cave layouts reuse the same
generation techniques Aevoria Simulator already uses for its resource
nodes (see that project's `ProceduralArtGenerator` C++ class) rather
than inventing a second one from scratch.

## Tech stack

- **Godot 4**, GDScript for game logic and UI.
- **C++ GDExtension** (this repo's `src/`) for procedural terrain/ore
  generation and any per-frame-costly systems -- same split as Aevoria
  Simulator: C++ for generation/performance, GDScript for behavior.
- Godot project lives under `godot/`, C++ source under `src/`.

## Status

Stub only -- folder structure and build scaffolding in place, no
gameplay yet. Not yet a git repository; init and push when ready to
start real work.

## Getting started (once real work begins)

1. `git init`, then add `godot-cpp` as a submodule (see `SConstruct`
   for the expected layout -- same pattern as Aevoria Simulator's
   `.gitmodules`).
2. `scons` to build the GDExtension into `godot/bin/`.
3. Open `godot/project.godot` in Godot 4.
