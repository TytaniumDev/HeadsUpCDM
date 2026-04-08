#!/usr/bin/env bash
set -euo pipefail

echo "=== Validating .toc file exists ==="
if [ ! -f HeadsUpCDM.toc ]; then
  echo "ERROR: HeadsUpCDM.toc not found" >&2
  exit 1
fi

echo "=== Checking all .toc source files exist ==="
# Skip libs/ entries — libraries are gitignored and fetched at release time by BigWigsMods packager
grep -E '^[^#].*\.(lua|xml)$' HeadsUpCDM.toc | grep -v '^libs/' | while IFS= read -r file; do
  if [ ! -f "$file" ]; then
    echo "ERROR: $file listed in .toc but not found on disk" >&2
    exit 1
  fi
done

echo "Build validation passed."
