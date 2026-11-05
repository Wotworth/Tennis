#!/usr/bin/env bash
# PHO-10: fails if release shrinking renamed any ML Kit class (the cause of the 6 Nov bug).
# Usage: check-mlkit-kept.sh <mapping.txt>
set -euo pipefail
map="${1:?mapping.txt}"
bad=$(grep -E '^com\.google\.(mlkit|android\.gms\.internal\.mlkit_)[^ ]* -> ' "$map" | awk '{ src=$1; dst=$3; sub(/:$/, "", dst); if (src != dst) print src " -> " dst }' | head -20)
if [ -n "$bad" ]; then echo "FAIL: ML Kit classes were renamed by shrinking:"; echo "$bad"; exit 1; fi
n=$(grep -cE '^com\.google\.mlkit\.' "$map" || true)
echo "PASS: all $n ML Kit classes kept under their own names"
