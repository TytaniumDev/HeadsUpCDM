#!/usr/bin/env bash
set -euo pipefail

# Ensure busted is installed
"$(dirname "$0")/install-luarocks-dep.sh" busted

# Ensure local luarocks bin is in PATH if luarocks is available
if command -v luarocks &> /dev/null; then
  eval "$(luarocks path --bin)"
fi

echo "=== Running busted tests ==="
busted
