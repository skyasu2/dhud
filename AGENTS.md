한국어 우선, 기술 용어는 영어 병기 가능
# Repository Guidelines

## Project Structure & Modules
- Root layout: `DHUDLITE/` (active addon), `DHUD/` (reference only), `DHUD_Options/` (optional LoD options).
- Entrypoint: `DHUDLITE/DHUDLITE.toc` (`Interface: 120000`, `SavedVariables: DHUDLITE_DB`).
- Key folders in `DHUDLITE/`:
  - `Data/` trackers (health, power, cast, combo, unit info).
  - `GUI/` rendering (textures, layout, bar/cast renderers).
  - `Slots/` HUD components (bars, resource, unit info, icons).
  - Core files: `Core.lua` (class/EventBus), `Settings.lua`, `AlphaManager.lua`, `HUDManager.lua`, `Main.lua`.

## Build, Test, and Dev
- No build step. Copy or symlink `DHUDLITE/` to your WoW `Interface/AddOns/` and reload UI.
  - Example: `_retail_/Interface/AddOns/DHUDLITE/` then run `/reload`.
- Useful in-game commands:
  - `/dhudlite`, `/dhud` (help); `/dhudlite reset`, `show`, `hide`, `alpha`.
- Pack release (optional): `git archive -o DHUDLITE-<ver>.zip HEAD:DHUDLITE`.

## Coding Style & Naming
- Language: Lua; indentation: 4 spaces; no tabs.
- File names: PascalCase; settings keys: camelCase (see `Settings.lua`).
- Namespace: attach APIs under `ns.*`; avoid new globals; prefer `local`.
- Events: `ns.events:On(event, obj, fn)` and `ns.events:Fire(event, ...)`.
- No external deps (Ace3/LibStub). Keep code small, clear, and UI/UX-faithful to original DHUD.

## Testing Guidelines
- Manual, in-game verification. Minimum checklist:
  - Player/target bars update; cast bars show; resource widgets match class.
  - Alpha states change (combat/target/rest/idle).
  - Slash commands work; `/dhudlite reset` restores defaults (`DHUDLITE_DB`).
- Reproduce on WoW 12.0.0; capture screenshots for regressions.

## Commits & Pull Requests
- Commits: imperative, concise subjects (seen in history: “Add …”, “Remove …”).
  - Example: `feat(gui): improve cast bar latency tick`.
- PRs must include:
  - Clear description and scope; linked issues; before/after screenshots; manual test plan; notes on SavedVariables impact.
  - Bump `.toc` `Version:` when releasing; update README if user-facing behavior changes.

## Security & Config Tips
- Maintain Secret Values compatibility: avoid deprecated/protected APIs; prefer periodic updates over insecure hooks.
- Do not taint global UI; avoid new frames in combat unless secure.
- Respect `SavedVariables` schema; add defaults in `Settings.lua` and provide reset paths.
