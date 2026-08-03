#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include "sfx_generator.h"

using namespace godot;

// TODO: register more real GDExtension classes here as they're written --
// e.g. procedural terrain/ore generation, ported from or sharing code
// with Aevoria Simulator's ProceduralArtGenerator.
void initialize_asteroid_miner_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(SfxGenerator);
}

void uninitialize_asteroid_miner_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
}

extern "C" {

GDExtensionBool GDE_EXPORT gdextension_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization
) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_asteroid_miner_module);
    init_obj.register_terminator(uninitialize_asteroid_miner_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}

}
