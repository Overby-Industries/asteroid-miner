#ifndef ASTEROID_MINER_SFX_GENERATOR_H
#define ASTEROID_MINER_SFX_GENERATOR_H

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Procedurally synthesizes every sound effect the game uses -- no .wav
// assets on disk, matching the rest of the project's generate-everything-
// from-code approach (terrain, ore glints, etc). Each method renders a
// short 16-bit mono buffer and returns it as a ready-to-play
// AudioStreamWAV. Called once at startup and cached by scripts/sfx.gd;
// not meant to be re-synthesized every play.
class SfxGenerator : public RefCounted {
    GDCLASS(SfxGenerator, RefCounted);

protected:
    static void _bind_methods();

public:
    static Ref<AudioStreamWAV> dig_hit();
    static Ref<AudioStreamWAV> ore_pickup(int ore_type);
    static Ref<AudioStreamWAV> thruster_loop();
    static Ref<AudioStreamWAV> low_resource_alarm();
    static Ref<AudioStreamWAV> cave_in_rumble();
    static Ref<AudioStreamWAV> heat_vent_hiss();
    static Ref<AudioStreamWAV> vent_blast();
    static Ref<AudioStreamWAV> dock_chime();
    static Ref<AudioStreamWAV> death_buzz();
    static Ref<AudioStreamWAV> level_complete_sweep();
    static Ref<AudioStreamWAV> menu_blip();
    static Ref<AudioStreamWAV> mothership_thump();
};

} // namespace godot

#endif // ASTEROID_MINER_SFX_GENERATOR_H
