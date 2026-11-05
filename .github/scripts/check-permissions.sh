#!/usr/bin/env bash
# NFR-05: fail if the given manifest declares a permission outside ci/allowed-permissions.txt.
# INTERNET is not on the list until PH-4 (PHO-23).
# Usage: check-permissions.sh <AndroidManifest.xml> [allowed-list]
set -euo pipefail
manifest="${1:?usage: check-permissions.sh <AndroidManifest.xml> [allowed-list]}"
allowed="${2:-ci/allowed-permissions.txt}"
[ -f "$manifest" ] || { echo "Manifest not found: $manifest" >&2; exit 2; }
found=$(grep -oE '<uses-permission(-sdk-23)?[^>]*android:name="[^"]+"' "$manifest" | grep -oE 'name="[^"]+"' | cut -d'"' -f2 | sort -u)
bad=0
for p in $found; do
  if grep -qxF "$p" <(grep -v '^#' "$allowed"); then echo "ok   $p"; else echo "FAIL $p is not allowed"; bad=1; fi
done
[ "$bad" = 0 ] && echo "PASS: every permission in $manifest is on the allowed list"
exit $bad
