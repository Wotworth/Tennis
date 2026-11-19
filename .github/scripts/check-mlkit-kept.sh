#!/usr/bin/env bash
# PHO-10: fails if release shrinking renamed any ML Kit class (the cause of the 6 Nov bug).
# Usage: check-mlkit-kept.sh <mapping.txt>
#
# One kind of entry is not ML Kit's and is let through (19 Nov): a helper class the shrinker
# writes itself from code repeated across the app. It files the helper under the name of the
# class where it first met the code, which can be an ML Kit class, then gives it a short name.
# ML Kit cannot look such a class up by name, because it did not exist when ML Kit was built.
# The mapping file marks these itself, on the lines under the class:
#   # {"id":"com.android.tools.r8.synthesized"}
# Only that mark lets a renamed class through; a name that merely looks like a helper does not.
set -euo pipefail
map="${1:?mapping.txt}"
out=$(awk '
  function settle() {
    if (pending != "") print (made ? "MADE " : "BAD ") pending
    pending = ""; made = 0
  }
  /^#/ { if (pending != "" && index($0, "\"id\":\"com.android.tools.r8.synthesized\"")) made = 1; next }
  /^[^ \t]/ {
    settle()
    if ($0 ~ /^com\.google\.(mlkit|android\.gms\.internal\.mlkit_)[^ ]* -> /) {
      src = $1; dst = $3; sub(/:$/, "", dst)
      if (src != dst) pending = src " -> " dst
    }
    next
  }
  { settle() }
  END { settle() }
' "$map")
bad=$(printf '%s\n' "$out" | sed -n 's/^BAD //p' | head -20)
helpers=$(printf '%s\n' "$out" | sed -n 's/^MADE //p')
if [ -n "$bad" ]; then echo "FAIL: ML Kit classes were renamed by shrinking:"; echo "$bad"; exit 1; fi
n=$(grep -cE '^com\.google\.mlkit\.' "$map" || true)
echo "PASS: all $n ML Kit classes kept under their own names"
if [ -n "$helpers" ]; then
  echo "Not ML Kit's own (helpers the shrinker made and marked as its own, filed under an ML Kit name):"
  echo "$helpers"
fi
