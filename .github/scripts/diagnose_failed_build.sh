#!/usr/bin/env bash
set -euo pipefail
printf "Running diagnose for keymap files (lines + hex around typical failure area)\n"
FILES=$(find config -type f -name '*.keymap' || true)
if [[ -z "$FILES" ]]; then
  printf "No keymap files found under config/\n"
  exit 0
fi
for F in $FILES; do
  printf "\n==> FILE: %s\n" "$F"
  printf "file -bi: "
  file -bi "$F" || true
  printf "\n--- Lines 1..120 (with numbers) ---\n"
  nl -ba -w3 -s': ' "$F" | sed -n '1,120p'
  printf "\n--- Lines 28..36 (context around reported failure) ---\n"
  nl -ba -w3 -s': ' "$F" | sed -n '28,36p'
  printf "\n--- Hex/bytes of lines 28..36 ---\n"
  sed -n '28,36p' "$F" | nl -ba -w3 -s': ' | while read -r L; do
    LN=$(printf "%s" "$L" | cut -d: -f1)
    LINE_CONTENT=$(sed -n "${LN}p" "$F" || true)
    printf "\nLine %s text: %s\n" "$LN" "$LINE_CONTENT"
    printf "Line %s as hex:\n" "$LN"
    sed -n "${LN}p" "$F" | xxd -g 1 -u || true
    printf "Line %s visible chars (cat -A):\n" "$LN"
    sed -n "${LN}p" "$F" | cat -A -v || true
  done
done
