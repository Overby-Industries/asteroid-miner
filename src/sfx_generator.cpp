#include "sfx_generator.h"

#include <godot_cpp/core/class_db.hpp>

#include <cmath>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {

constexpr int SAMPLE_RATE = 44100;
constexpr float TAU_F = 6.28318530717958647692f;

// Tiny deterministic PRNG so every synthesized sound is stable across runs
// and exports instead of depending on Godot's global RNG state.
struct Rng {
    uint32_t state;
    explicit Rng(uint32_t seed) : state(seed ? seed : 1) {}
    float next() {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return (float)state / 4294967295.0f * 2.0f - 1.0f;
    }
};

float clampf(float v, float lo, float hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

int seconds_to_frames(float seconds) {
    return (int)(seconds * SAMPLE_RATE);
}

// Linear attack into a shaped decay, both normalized to the buffer's 0..1
// time axis. decay_shape > 1 makes the tail fall off faster than linear.
float env_ad(float t01, float attack01, float decay_shape) {
    if (t01 < attack01) {
        return t01 / attack01;
    }
    float d = (t01 - attack01) / (1.0f - attack01);
    return powf(1.0f - clampf(d, 0.0f, 1.0f), decay_shape);
}

// One-pole lowpass run in-place; cutoff01 in (0,1], lower = darker/muddier.
void lowpass(std::vector<float> &buf, float cutoff01) {
    float y = 0.0f;
    for (float &s : buf) {
        y += cutoff01 * (s - y);
        s = y;
    }
}

// Fades the first/last `frames` samples to zero so a looping buffer doesn't
// click at the seam where it wraps.
void fade_edges(std::vector<float> &buf, int frames) {
    int n = (int)buf.size();
    frames = frames < n / 2 ? frames : n / 2;
    for (int i = 0; i < frames; i++) {
        float g = (float)i / frames;
        buf[i] *= g;
        buf[n - 1 - i] *= g;
    }
}

Ref<AudioStreamWAV> to_stream(const std::vector<float> &samples) {
    PackedByteArray bytes;
    bytes.resize((int64_t)samples.size() * 2);
    for (size_t i = 0; i < samples.size(); i++) {
        int16_t v = (int16_t)(clampf(samples[i], -1.0f, 1.0f) * 32767.0f);
        bytes.set((int64_t)i * 2, v & 0xFF);
        bytes.set((int64_t)i * 2 + 1, (v >> 8) & 0xFF);
    }
    Ref<AudioStreamWAV> stream;
    stream.instantiate();
    stream->set_format(AudioStreamWAV::FORMAT_16_BITS);
    stream->set_mix_rate(SAMPLE_RATE);
    stream->set_stereo(false);
    stream->set_data(bytes);
    return stream;
}

Ref<AudioStreamWAV> to_looping_stream(const std::vector<float> &samples) {
    Ref<AudioStreamWAV> stream = to_stream(samples);
    stream->set_loop_mode(AudioStreamWAV::LOOP_FORWARD);
    stream->set_loop_begin(0);
    stream->set_loop_end((int32_t)samples.size());
    return stream;
}

} // namespace

void SfxGenerator::_bind_methods() {
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("dig_hit"), &SfxGenerator::dig_hit);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("ore_pickup", "ore_type"), &SfxGenerator::ore_pickup);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("thruster_loop"), &SfxGenerator::thruster_loop);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("low_resource_alarm"), &SfxGenerator::low_resource_alarm);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("cave_in_rumble"), &SfxGenerator::cave_in_rumble);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("heat_vent_hiss"), &SfxGenerator::heat_vent_hiss);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("vent_blast"), &SfxGenerator::vent_blast);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("dock_chime"), &SfxGenerator::dock_chime);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("death_buzz"), &SfxGenerator::death_buzz);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("level_complete_sweep"), &SfxGenerator::level_complete_sweep);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("menu_blip"), &SfxGenerator::menu_blip);
    ClassDB::bind_static_method("SfxGenerator", D_METHOD("mothership_thump"), &SfxGenerator::mothership_thump);
}

// Short crunchy click + a soft low thump -- a chunk of rock breaking loose.
Ref<AudioStreamWAV> SfxGenerator::dig_hit() {
    int n = seconds_to_frames(0.10f);
    std::vector<float> buf(n);
    Rng rng(12345);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = powf(1.0f - t, 6.0f);
        float noise_part = rng.next() * env;
        float thump = sinf(TAU_F * 90.0f * i / SAMPLE_RATE) * env * env;
        buf[i] = noise_part * 0.5f + thump * 0.6f;
    }
    lowpass(buf, 0.5f);
    return to_stream(buf);
}

// Two-note rising chime; pitch varies by ore so cargo feedback is
// distinguishable by ear (0 = gold, 1 = nickel, 2 = fuel ore).
Ref<AudioStreamWAV> SfxGenerator::ore_pickup(int ore_type) {
    float base_freq = 880.0f;
    if (ore_type == 1) {
        base_freq = 660.0f;
    } else if (ore_type == 2) {
        base_freq = 520.0f;
    }
    int n = seconds_to_frames(0.22f);
    std::vector<float> buf(n);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = env_ad(t, 0.05f, 2.5f);
        float note = t < 0.5f ? base_freq : base_freq * 1.5f;
        buf[i] = sinf(TAU_F * note * i / SAMPLE_RATE) * env * 0.5f;
    }
    return to_stream(buf);
}

// Looping low engine hum -- filtered noise plus a sub-bass fundamental.
Ref<AudioStreamWAV> SfxGenerator::thruster_loop() {
    int n = seconds_to_frames(0.4f);
    std::vector<float> buf(n);
    Rng rng(999);
    for (int i = 0; i < n; i++) {
        float hum = sinf(TAU_F * 70.0f * i / SAMPLE_RATE) * 0.35f;
        float overtone = sinf(TAU_F * 140.0f * i / SAMPLE_RATE) * 0.15f;
        buf[i] = hum + overtone + rng.next() * 0.08f;
    }
    lowpass(buf, 0.35f);
    fade_edges(buf, seconds_to_frames(0.01f));
    return to_looping_stream(buf);
}

// Short urgent beep -- meant to be re-triggered by a cooldown timer in
// GDScript while O2 or fuel is critically low, not looped internally.
Ref<AudioStreamWAV> SfxGenerator::low_resource_alarm() {
    int n = seconds_to_frames(0.15f);
    std::vector<float> buf(n);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = env_ad(t, 0.1f, 1.5f);
        buf[i] = sinf(TAU_F * 740.0f * i / SAMPLE_RATE) * env * 0.55f;
    }
    return to_stream(buf);
}

// Deep filtered-noise rumble with three staggered low thumps, for a
// fracture chain-reaction collapsing.
Ref<AudioStreamWAV> SfxGenerator::cave_in_rumble() {
    int n = seconds_to_frames(0.7f);
    std::vector<float> buf(n);
    Rng rng(4242);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = powf(1.0f - t, 2.0f);
        buf[i] = rng.next() * env;
    }
    lowpass(buf, 0.12f);

    int pulses[3] = { 0, n / 4, n / 2 };
    int pulse_len = seconds_to_frames(0.12f);
    for (int p = 0; p < 3; p++) {
        int start = pulses[p];
        for (int i = 0; i < pulse_len && start + i < n; i++) {
            float t = (float)i / pulse_len;
            float env = powf(1.0f - t, 4.0f);
            buf[start + i] += sinf(TAU_F * 55.0f * i / SAMPLE_RATE) * env * 0.5f;
        }
    }
    return to_stream(buf);
}

// Looping breathy hiss (crude noise-minus-its-own-lowpass highpass) with a
// slow amplitude wobble and a faint low drone -- ambient danger cue for
// lingering near a heat vent.
Ref<AudioStreamWAV> SfxGenerator::heat_vent_hiss() {
    int n = seconds_to_frames(1.0f);
    std::vector<float> raw(n);
    Rng rng(777);
    for (int i = 0; i < n; i++) {
        raw[i] = rng.next();
    }
    std::vector<float> filtered = raw;
    lowpass(filtered, 0.15f);

    std::vector<float> buf(n);
    for (int i = 0; i < n; i++) {
        float hiss = raw[i] - filtered[i];
        float wobble = 0.6f + 0.4f * sinf(TAU_F * 2.0f * i / SAMPLE_RATE);
        float drone = sinf(TAU_F * 110.0f * i / SAMPLE_RATE) * 0.12f;
        buf[i] = (hiss * 0.5f + drone) * wobble;
    }
    fade_edges(buf, seconds_to_frames(0.02f));
    return to_looping_stream(buf);
}

// Rising-then-falling noise burst with a downward pitch sweep -- the
// surface vent's eruption blast.
Ref<AudioStreamWAV> SfxGenerator::vent_blast() {
    int n = seconds_to_frames(0.5f);
    std::vector<float> buf(n);
    Rng rng(31337);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = t < 0.1f ? t / 0.1f : powf(1.0f - (t - 0.1f) / 0.9f, 2.0f);
        float freq = 220.0f * (1.0f - t) + 40.0f;
        float tone = sinf(TAU_F * freq * i / SAMPLE_RATE);
        buf[i] = (rng.next() * 0.6f + tone * 0.5f) * env;
    }
    lowpass(buf, 0.4f);
    return to_stream(buf);
}

// Pleasant three-note ascending arpeggio (C5 E5 G5) -- cargo banked / dock.
Ref<AudioStreamWAV> SfxGenerator::dock_chime() {
    float notes[3] = { 523.25f, 659.25f, 784.0f };
    int note_len = seconds_to_frames(0.13f);
    int n = note_len * 3;
    std::vector<float> buf(n);
    for (int note = 0; note < 3; note++) {
        for (int i = 0; i < note_len; i++) {
            float t = (float)i / note_len;
            float env = env_ad(t, 0.08f, 2.0f);
            buf[note * note_len + i] = sinf(TAU_F * notes[note] * i / SAMPLE_RATE) * env * 0.5f;
        }
    }
    return to_stream(buf);
}

// Harsh downward-sweeping square-ish buzz for a hazard death.
Ref<AudioStreamWAV> SfxGenerator::death_buzz() {
    int n = seconds_to_frames(0.8f);
    std::vector<float> buf(n);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = powf(1.0f - t, 1.5f);
        float freq = 220.0f * powf(0.2f, t);
        float wave = sinf(TAU_F * freq * i / SAMPLE_RATE) > 0.0f ? 1.0f : -1.0f;
        buf[i] = wave * env * 0.35f;
    }
    lowpass(buf, 0.6f);
    return to_stream(buf);
}

// Four-note triumphant ascending arpeggio (C5 E5 G5 C6) with a soft octave
// harmony -- level quota met / advancing.
Ref<AudioStreamWAV> SfxGenerator::level_complete_sweep() {
    float notes[4] = { 523.25f, 659.25f, 784.0f, 1046.5f };
    int note_len = seconds_to_frames(0.14f);
    int n = note_len * 4;
    std::vector<float> buf(n);
    for (int note = 0; note < 4; note++) {
        for (int i = 0; i < note_len; i++) {
            float t = (float)i / note_len;
            float env = env_ad(t, 0.05f, 2.0f);
            float harmony = sinf(TAU_F * notes[note] * 2.0f * i / SAMPLE_RATE) * 0.15f;
            buf[note * note_len + i] = (sinf(TAU_F * notes[note] * i / SAMPLE_RATE) * 0.5f + harmony) * env;
        }
    }
    return to_stream(buf);
}

// Soft, short UI blip -- menu launch / cutscene skip acknowledgement.
Ref<AudioStreamWAV> SfxGenerator::menu_blip() {
    int n = seconds_to_frames(0.06f);
    std::vector<float> buf(n);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = powf(1.0f - t, 3.0f);
        buf[i] = sinf(TAU_F * 600.0f * i / SAMPLE_RATE) * env * 0.4f;
    }
    return to_stream(buf);
}

// Deep boom with a brief noise transient -- mothership touchdown, paired
// with the existing camera shake.
Ref<AudioStreamWAV> SfxGenerator::mothership_thump() {
    int n = seconds_to_frames(0.6f);
    std::vector<float> buf(n);
    Rng rng(2024);
    for (int i = 0; i < n; i++) {
        float t = (float)i / n;
        float env = powf(1.0f - t, 3.0f);
        float freq = 65.0f * (1.0f - 0.3f * t);
        float thud = sinf(TAU_F * freq * i / SAMPLE_RATE) * env;
        float transient = t < 0.03f ? rng.next() * (1.0f - t / 0.03f) : 0.0f;
        buf[i] = thud * 0.7f + transient * 0.5f;
    }
    return to_stream(buf);
}
