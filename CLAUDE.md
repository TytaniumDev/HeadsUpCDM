# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HeadsUpCDM is a World of Warcraft addon (Lua, WoW API) that provides a cooldown manager and rotation helper displayed at eye level so the player never has to look away from the action. It uses the AceAddon-3.0 framework.

## Commands

### Lint
```bash
luacheck src/ tests/
```

### Test
```bash
busted
```
Tests use the [busted](https://olivinelabs.com/busted/) framework. Config is in `.busted` — tests live in `tests/` with the `test_` prefix pattern.

### Run a single test file
```bash
busted tests/test_config.lua
```

### Build validation
```bash
bash scripts/build.sh
```
Checks that the `.toc` file exists and all source files listed in it are present on disk.

## Architecture

### Global namespace pattern
The addon registers itself as `HeadsUpCDM` via AceAddon in `src/Config.lua`, stored in `_G.HeadsUpCDM`. Every other source file accesses it via `local HUCDM = _G.HeadsUpCDM` and attaches methods/data to it. There is no module system — all files share the single `HUCDM` table.

### File load order (defined by `HeadsUpCDM.toc`)
1. **Config.lua** — Creates the addon object, defines constants and saved variable defaults
2. **Core.lua** — Addon lifecycle (`OnInitialize`/`OnEnable`), slash commands (`/hucdm`, `/headsupcdm`), event handlers

### Test structure
Tests stub WoW APIs and `LibStub` at the top of each file, then `dofile()` the source files in load order. The test stubs pattern is consistent across all test files — copy from an existing test when adding new ones.

## Git Workflow

- **Never push directly to `main`.** Always create a feature branch, push there, and open a PR.
- When using `/commit-push`, push to the current feature branch (not `origin main`).

## WoW API Version

This addon targets **WoW 12.0 (Midnight)** (`## Interface: 120001`). Use the modern `C_` namespaced APIs — do not use their deprecated predecessors:

| Deprecated (do NOT use) | Use instead |
|---|---|
| `GetSpecialization()` | `C_SpecializationInfo.GetSpecialization()` |
| `GetSpecializationInfo()` | `C_SpecializationInfo.GetSpecializationInfo()` |
| `SendChatMessage()` | `C_ChatInfo.SendChatMessage()` |
| `InviteUnit()` | `C_PartyInfo.InviteUnit()` |

When adding new WoW API calls, check [Warcraft Wiki API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) to confirm the function hasn't been removed or moved to a `C_` namespace in 12.0.

## Key Conventions

- Lua 5.1 target (`std = "lua51"` in `.luacheckrc`), 120 char line limit
- Table append idiom: `t[#t + 1] = value` (not `table.insert`)
- External libraries (Ace3, LibStub, etc.) are fetched at release time by BigWigsMods packager per `.pkgmeta` — the `libs/` dir is gitignored
- **CI job naming constraint:** `.github/workflows/ci-shared.yml` is a reusable workflow (`workflow_call` only) that defines three jobs: `Lint`, `Build`, `Test`. It is called by `.github/workflows/ci.yml` (trigger: `pull_request` only) via a calling job with ID `CI`. GitHub Actions names reusable workflow checks as `<calling_job_id> / <reusable_job_id>`, producing `CI / Lint`, `CI / Build`, `CI / Test` — which branch protection requires. Do not rename the calling job ID in `ci.yml` or the job IDs in `ci-shared.yml`, and do not add extra triggers to `ci.yml`.
- **Never `git add -f` gitignored files.** If a path is in `.gitignore` (e.g. `docs/superpowers/`), respect that — do not force-add or force-commit it. Those files are local-only by design.
