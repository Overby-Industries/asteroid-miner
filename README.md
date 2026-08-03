# Asteroid Miner (working title)

[![Version](https://img.shields.io/badge/Version-1.0.2--Alpha-blue?style=for-the-badge&logo=github)](https://github.com/Overby-Industries/asteroid-miner/releases)
[![Play on itch.io](https://img.shields.io/badge/Play_on-itch.io-fa5c5c?style=for-the-badge&logo=itchdotio)](https://aevoria-simulator.itch.io/asteroid-miner)

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

First playable core loop is in: dig from the mothership into a
procedurally generated asteroid, manage O2/fuel, bank ore, and get back
before you run out. Hazards implemented: fracture cave-ins, deep heat
vents, and a timed surface vent gate guarding the way back. All gameplay
lives in GDScript under `godot/scripts/`; the C++ GDExtension (`src/`)
is still an empty stub, reserved for later if procedural generation
needs to get heavier.

## Getting started

1. `git submodule update --init` to pull in `godot-cpp` (already added
   as a submodule -- see `.gitmodules`).
2. `scons platform=<windows|linux|macos> target=template_debug` to
   build the GDExtension into `godot/bin/` (currently a stub, but
   required for the project to open without errors).
3. Open `godot/project.godot` in Godot 4.6 and run -- `main.tscn` is
   the main scene.
