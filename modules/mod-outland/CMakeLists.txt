# Outland Project Core Module

set(MOD_OUTLAND_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# --- Config Data ---
set(MOD_OUTLAND_CONFIG
    ${MOD_OUTLAND_ROOT}/conf/mod-outland.conf.dist
)

# --- Source Files ---
# This section instructs the build system to compile our C++ loader file,
# which resolves the linker error.
set(MOD_OUTLAND_SOURCES
    ${MOD_OUTLAND_ROOT}/src/mod-outland_loader.cpp
)

# --- SQL Data ---
# World
set(MOD_OUTLAND_WORLD_SQL
    ${MOD_OUTLAND_ROOT}/data/sql/db-world/001_outland_initial_spawn_settings.sql
    ${MOD_OUTLAND_ROOT}/data/sql/db-world/002_outland_clean_world_spawns.sql
)

# --- Lua Scripts ---
set(MOD_OUTLAND_LUA_SCRIPTS
    ${MOD_OUTLAND_ROOT}/data/lua_scripts/outland_survival.lua
)

foreach(MOD_OUTLAND_LUA_SCRIPT ${MOD_OUTLAND_LUA_SCRIPTS})
    get_filename_component(MOD_OUTLAND_LUA_SCRIPT_NAME ${MOD_OUTLAND_LUA_SCRIPT} NAME)
    add_custom_command(TARGET modules POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${MOD_OUTLAND_LUA_SCRIPT} "${CMAKE_BINARY_DIR}/bin/lua_scripts/${MOD_OUTLAND_LUA_SCRIPT_NAME}"
    )
endforeach()
