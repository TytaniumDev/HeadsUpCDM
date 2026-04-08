#!/usr/bin/env bash
set -euo pipefail

# Removes the dev symlink and restores the Wago-managed addon.
# Counterpart to: scripts/dev-link.sh

WOW_ADDONS="${WOW_ADDONS_PATH:-/Applications/World of Warcraft/_retail_/Interface/AddOns}"
ADDON_DIR="$WOW_ADDONS/HeadsUpCDM"
BACKUP_DIR="$WOW_ADDONS/HeadsUpCDM.wago-backup"

if [ ! -L "$ADDON_DIR" ]; then
  echo "Not in dev mode — $ADDON_DIR is not a symlink."
  exit 0
fi

echo "Removing dev symlink..."
rm "$ADDON_DIR"

if [ -d "$BACKUP_DIR" ]; then
  echo "Restoring Wago backup..."
  mv "$BACKUP_DIR" "$ADDON_DIR"
  echo "Done! Wago-managed version restored."
else
  echo "WARNING: No backup found at $BACKUP_DIR" >&2
  echo "Re-install HeadsUpCDM via Wago to restore." >&2
fi
