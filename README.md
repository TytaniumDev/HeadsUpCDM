# HeadsUpCDM

A cooldown manager and rotation helper addon for World of Warcraft that displays cooldowns at eye level, so you never have to look away from the action.

## Features

- Cooldown tracking displayed near the center of your screen
- Rotation helper suggestions at eye level
- Draggable, lockable display
- Per-character saved settings
- Lightweight and performant

## Installation

Install via [CurseForge](https://www.curseforge.com/) or [Wago](https://addons.wago.io/).

Requires **WoW 12.0 (Midnight)** or later.

## Slash Commands

- `/hucdm` or `/headsupcdm` — Toggle the display
- `/hucdm lock` — Lock the display position
- `/hucdm unlock` — Unlock for repositioning
- `/hucdm reset` — Reset position to default

## Development

### Prerequisites

- [Lua 5.1](https://www.lua.org/)
- [LuaRocks](https://luarocks.org/)

### Lint

```bash
luacheck src/ tests/
```

### Test

```bash
busted
```

### Build Validation

```bash
bash scripts/build.sh
```

### Dev Mode

```bash
scripts/dev-link.sh    # Symlink repo into WoW AddOns folder
scripts/dev-unlink.sh  # Restore Wago-managed version
```
