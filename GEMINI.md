# HeadsUpCDM - Gemini Context

HeadsUpCDM is a World of Warcraft addon (Lua) that provides a cooldown manager and rotation helper displayed at eye level so the player never has to look away from the action. It targets WoW 12.0 (Midnight) and utilizes the AceAddon-3.0 framework for its core structure.

## Project Overview

- **Purpose:** Display cooldown timers and rotation suggestions near the center of the screen for minimal eye movement during combat.
- **Tech Stack:** Lua (target 5.1), Ace3 Framework (Addon, Event, Console, DB).
- **Architecture:**
    - **Global Namespace:** The addon object is stored in `_G.HeadsUpCDM` (aliased as `HUCDM` locally).
    - **Saved Variables:** Per-character settings stored in `HeadsUpCDMDB` via AceDB.

## Building and Running

WoW addons do not require a traditional build step, but this project includes validation and quality tools.

- **Linting:**
  ```bash
  luacheck src/ tests/
  ```
- **Testing:**
  ```bash
  busted
  ```
  Tests are located in the `tests/` directory and use the `busted` framework with WoW API stubs.
- **Validation:**
  ```bash
  bash scripts/build.sh
  ```
  Verifies that the `.toc` file is correct and all required source files are present.
- **Development:** Link the repository to your WoW `Interface/AddOns/HeadsUpCDM` directory to test in-game.

## Development Conventions

- **WoW 12.0 API:** Exclusively use modern `C_` namespaced APIs (e.g., `C_Timer`, `C_SpecializationInfo`). Do not use deprecated global functions.
- **File Load Order:** Defined in `HeadsUpCDM.toc`. Core configuration must be loaded before logic and UI.
- **Coding Style:**
    - 120 character line limit.
    - Lua 5.1 compatibility.
    - Use `HUCDM` local alias for the global namespace.
    - Append to tables using `t[#t + 1] = value`.
- **Testing Pattern:** Always stub WoW APIs and `LibStub` at the beginning of test files, then use `dofile()` to load source files in order.

## Key Files

- `HeadsUpCDM.toc`: Metadata and file load order.
- `src/Config.lua`: Constants and default settings.
- `src/Core.lua`: Addon lifecycle, slash commands, and event handlers.
- `CLAUDE.md`: Detailed engineering standards and workflow instructions for AI agents.
