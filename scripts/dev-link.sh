#!/usr/bin/env bash
set -euo pipefail

# Symlinks this repo into WoW's AddOns folder for live development.
# After linking, edit files and /reload in-game to pick up changes.
# Undo with: scripts/dev-unlink.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WOW_ADDONS="${WOW_ADDONS_PATH:-/Applications/World of Warcraft/_retail_/Interface/AddOns}"
ADDON_DIR="$WOW_ADDONS/HeadsUpCDM"
BACKUP_DIR="$WOW_ADDONS/HeadsUpCDM.wago-backup"

# --- Preflight checks ---

if [ ! -d "$WOW_ADDONS" ]; then
  echo "ERROR: WoW AddOns directory not found at: $WOW_ADDONS" >&2
  echo "Set WOW_ADDONS_PATH to override." >&2
  exit 1
fi

if [ -L "$ADDON_DIR" ]; then
  echo "Already linked: $ADDON_DIR -> $(readlink "$ADDON_DIR")"
  exit 0
fi

if [ ! -e "$ADDON_DIR" ] && [ -d "$BACKUP_DIR" ]; then
  echo "Addon directory missing but backup exists — restoring from backup..."
  mv "$BACKUP_DIR" "$ADDON_DIR"
fi

if [ ! -d "$ADDON_DIR" ]; then
  echo "No existing HeadsUpCDM addon found — creating fresh symlink."
  ln -s "$REPO_ROOT" "$ADDON_DIR"
  echo ""
  echo "Done! Dev mode is active."
  echo "  Edit files in: $REPO_ROOT"
  echo "  Reload in WoW: /reload"
  echo "  To remove symlink: scripts/dev-unlink.sh"
  exit 0
fi

# --- Copy libs from Wago install into repo ---

echo "Copying libs from Wago install into repo..."
if [ -d "$ADDON_DIR/libs" ]; then
  rsync -a --delete "$ADDON_DIR/libs/" "$REPO_ROOT/libs/"
  echo "  Copied $(ls "$REPO_ROOT/libs/" | wc -l | tr -d ' ') libraries."
else
  echo "WARNING: No libs/ in Wago install — addon may fail to load." >&2
fi

# --- Back up Wago install and create symlink ---

echo "Backing up Wago install to HeadsUpCDM.wago-backup..."
if [ -d "$BACKUP_DIR" ]; then
  echo "  Replacing stale backup with current Wago install."
  rm -rf "$BACKUP_DIR"
fi
mv "$ADDON_DIR" "$BACKUP_DIR"

echo "Creating symlink: $ADDON_DIR -> $REPO_ROOT"
ln -s "$REPO_ROOT" "$ADDON_DIR"

echo ""
echo "Done! Dev mode is active."
echo "  Edit files in: $REPO_ROOT"
echo "  Reload in WoW: /reload"
echo "  To restore Wago version: scripts/dev-unlink.sh"
