#!/usr/bin/env bash
set -euo pipefail
FAIL=0
printf "Searching for keymap files in config/ ...\n"
FILES=$(find config -type f -name '*.keymap' || true)
if [[ -z "$FILES" ]]; then
  printf "No config/*.keymap files found. Skipping validation.\n"
  exit 0
fi
for F in $FILES; do
  printf "\n==> Inspecting: %s\n" "$F"
  file -bi "$F" || true
  printf "First 12 lines (visible ends):\n"
  sed -n '1,12p' "$F" | nl -ba -w3 -s': ' | sed -n '1,12p'
  printf "\nChecking BOM (UTF-8 BOM = EF BB BF): "
  head -c3 "$F" | xxd -p -c3 || true
  printf "\nSearching for non-ASCII bytes:\n"
  if grep -nP "[^\x00-\x7F]" "$F" >/dev/null 2>&1; then
    printf "  NON-ASCII bytes found in lines:\n"
    grep -nP "[^\x00-\x7F]" "$F" || true
    FAIL=1
  else
    printf "  none\n"
  fi
  printf "\nSearching for CRLF line endings:\n"
  if grep -n $'\r' "$F" >/dev/null 2>&1; then
    printf "  CR (\\r) bytes found (CRLF). Lines:\n"
    grep -n $'\r' "$F" || true
    FAIL=1
  else
    printf "  none\n"
  fi
  printf "\nSearching for BOMs explicitly (hex EFBBBF):\n"
  if head -c3 "$F" | grep -q $'\xEF\xBB\xBF'; then
    printf "  BOM detected\n"
    FAIL=1
  else
    printf "  none\n"
  fi
  printf "\nSearching for '//' or '/*' comment tokens (these break devicetree inside bindings):\n"
  if grep -n "//" "$F" >/dev/null 2>&1 || grep -n "/\\*" "$F" >/dev/null 2>&1; then
    printf "  Comment tokens found, printing occurrences with context:\n"
    grep -n -C2 -E "//|/\\*" "$F" || true
    grep -n -E "//|/\\*" "$F" | cut -d: -f1 | sort -u | while read -r LN; do
      printf "\n--- Context around line %s ---\n" "$LN"
      sed -n "$((LN-3)),$((LN+3))p" "$F" | nl -ba -w3 -s': '
      printf "\nHex of exact line %s:\n" "$LN"
      sed -n "${LN}p" "$F" | xxd -g 1 -u
      sed -n "${LN}p" "$F" | cat -A -v
    done
    FAIL=1
  else
    printf "  none\n"
  fi
  printf "\nSearching for control characters (except TAB and LF):\n"
  if LC_ALL=C grep -n '[^[:print:]\t\n]' "$F" >/dev/null 2>&1; then
    printf "  Control characters found in lines:\n"
    LC_ALL=C grep -n '[^[:print:]\t\n]' "$F" || true
    FAIL=1
  else
    printf "  none\n"
  fi

  printf "\nShow full file with line numbers (for reference):\n"
  nl -ba -w3 -s': ' "$F" | sed -n '1,300p'
done

if [[ "$FAIL" -ne 0 ]]; then
  printf "\nValidation failed: one or more keymap issues detected. Fix them and push again.\n"
  exit 2
fi
printf "\nAll keymap checks passed.\n"
