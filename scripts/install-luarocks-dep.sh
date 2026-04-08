#!/usr/bin/env bash
set -euo pipefail

# Helper script to install luarocks dependencies idempotently and OS-aware.
# Usage: ./scripts/install-luarocks-dep.sh <package_name>

PACKAGE_NAME=$1

if [ -z "$PACKAGE_NAME" ]; then
  echo "ERROR: Package name required." >&2
  exit 1
fi

# Check if package is already in PATH
if ! command -v "$PACKAGE_NAME" &> /dev/null; then
  echo "=== Installing $PACKAGE_NAME ==="
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get update -qq && sudo apt-get install -y -qq luarocks >/dev/null
    sudo luarocks install "$PACKAGE_NAME" >/dev/null
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v luarocks &> /dev/null; then
      echo "=== Installing luarocks via brew ==="
      brew install --quiet luarocks
    fi
    echo "=== Installing $PACKAGE_NAME via luarocks ==="
    luarocks install "$PACKAGE_NAME"
  else
    echo "ERROR: Unsupported OS for automatic installation. Please install '$PACKAGE_NAME' manually." >&2
    exit 1
  fi
fi
