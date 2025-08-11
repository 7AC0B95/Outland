# Copilot Project Instructions (Outland / AzerothCore Fork)

Purpose: Give AI agents just enough domain context to make correct, minimal, idiomatic changes fast. Keep answers concrete, cite paths. Prefer editing existing patterns over inventing new ones.

## 1. Big Picture
- Core: AzerothCore C++ game server (worldserver + authserver) with modular extension layer under `modules/` (static linkage here: see `build/build.sh` using `-DMODULES=static -DSCRIPTS=static`).
- Modules: Each `modules/mod-*` can ship C++ (`src/`), config (`conf/*.conf.dist`), Lua (`data/lua_scripts` via Eluna), SQL, and CI helpers (`apps/ci`). Extra per‑module CMake logic lives in `<module>/<module>.cmake` and is auto-included (e.g. `modules/mod-outland/mod-outland.cmake` copies Lua scripts into install `bin/lua_scripts/`).
- Lua Scripting: Enabled through `mod-eluna` (static). Hooks enumerated in `modules/mod-eluna/src/LuaEngine/Hooks.h`. Lua scripts loaded from the installed `env/dist/bin/lua_scripts/` directory.
- Configuration: Dist configs in `src/server/apps/*/*.conf.dist` and module confs (`modules/mod-outland/conf/mod-outland.conf.dist`). Users copy to `env/dist/etc/` at runtime.
- Databases: Accessed in Lua with `CharDBQuery/Execute` etc. Persistent per-character custom data pattern: create table if not exists, cache in a Lua STATE table keyed by `GetGUIDLow()`, periodic save (see `outland_survival.lua`).

## 2. Key Workflows
- Build (local custom script): `./build/build.sh` (sets Clang, install prefix `env/dist/`). Incremental: rerun Phase 2 (make) or use VS Code task "AzerothCore: Build" (`./acore.sh compiler build`). Clean: task "AzerothCore: Clean build".
- Interactive ops & utilities: `./acore.sh` menu (compiler, run-worldserver, run-authserver, module install/update, download client-data).
- Run servers (simple restarters): `./acore.sh run-worldserver` / `run-authserver` (also exposed as tasks). Binaries installed to `env/dist/bin/`.
- Tests:
  * C++ unit tests: target `unit_tests` (see `src/test/CMakeLists.txt`) – invoke after build: `./src/test/unit_tests` inside build dir.
  * Bash/app tests: `apps/test-framework/run-tests.sh --all` or `--dir <path>`; uses BATS helpers in `apps/test-framework/bats_libs/`.
- Codestyle: C++: `python apps/codestyle/codestyle-cpp.py`; SQL: `python apps/codestyle/codestyle-sql.py`; module-specific script example `modules/mod-outland/apps/ci/ci-codestyle.sh` (regex based).

## 3. Conventions & Patterns
- Module naming: `mod-<name>`; provide a stub loader in `src/<mod>_loader.cpp` with `Add<mod>Scripts()` and `AddCustomScripts()` (see `mod-outland/src/mod-outland_loader.cpp`).
- Extra CMake: Put `<mod>.cmake` at module root for post-target customization (e.g., copying assets, installing Lua). Use `install(DIRECTORY ...)` to place runtime resources under `${CMAKE_INSTALL_PREFIX}` (here `env/dist`).
- Lua persistent systems: Follow `modules/mod-outland/data/lua_scripts/outland_survival.lua` structure:
  * Config table at top (rates, thresholds).
  * STATE cache (avoid recomputing queries every tick).
  * `EnsureTable()` for idempotent schema creation.
  * Periodic tick via `CreateLuaEvent(interval_ms, 0)`; guard heavy work with gating conditions (BG/Arena/Flight/Ghost) and stage transitions (apply/remove auras atomically).
  * Save throttling (e.g. nextSave timestamp) to reduce DB writes.
- Avoid putting implementation scripts in `bin/` – that directory is an install target (see `bin/README.md`). Place sources in `modules/<mod>/...` and let CMake copy/install.
- Precompiled headers for modules: `modules/ModulesPCH.h` used when `USE_SCRIPTPCH` on; include common server headers only.
- Static vs dynamic modules: This fork pins to static; adding new module means ensuring `build/build.sh` (or CMake invocation) still uses `-DMODULES=static` so sources compile into worldserver.

## 4. Safe Change Guidelines
- Reuse existing helper patterns (copy & adapt `outland_survival.lua` for new per-character mechanics). Keep tick rate reasonable (`>= 1000ms`) and batch DB writes.
- When adding Lua events/items: Register with appropriate `RegisterPlayerEvent` / `RegisterItemEvent` constants. Unregistering not typically needed for static scripts.
- New persistent tables: Prefix with clear scope (e.g. `character_<feature>`), primary key `guid` if character-bound, and timestamps for offline processing if needed.
- Do not introduce tabs; codestyle scripts will fail. Limit blank consecutive lines to one.

## 5. Examples
- Copy assets pattern: see `mod-outland.cmake` loop copying `*.lua` and installing directory.
- Character state clamp pattern: `clamp(value, 0, Hunger.MAX)` before save.
- Command hook pattern: see `.hunger` parsing in `outland_survival.lua` (lowercase, pattern match, GM gating with `player:IsGM()`).

## 6. When Unsure
Prefer: inspect analogous module/script, mirror structure, minimal diff. Ask for which module or runtime target if ambiguity (authserver vs worldserver). Keep edits localized; avoid altering top-level CMake unless feature truly global.

(End)
