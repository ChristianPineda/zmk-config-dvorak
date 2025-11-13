#!/usr/bin/env bash
# Diagnose: muestra líneas de contexto y un desglose byte-a-byte para cada línea
# útil para localizar la columna/byte que provoca el error de devicetree.
set -euo pipefail

printf "Running diagnose for keymap files (lines + hex + per-byte detail)\n"
FILES=$(find config -type f -name '*.keymap' || true)
if [[ -z "$FILES" ]]; then
  printf "No keymap files found under config/\n"
  exit 0
fi

# Rango de líneas a inspeccionar alrededor del fallo reportado (ajusta si necesario)
START_LINE=28
END_LINE=36

for F in $FILES; do
  printf "\n==> FILE: %s\n" "$F"
  printf "file -bi: "
  file -bi "$F" || true

  printf "\n--- Lines 1..120 (with numbers) ---\n"
  nl -ba -w3 -s': ' "$F" | sed -n '1,120p'

  printf "\n--- Context lines %s..%s ---\n" "$START_LINE" "$END_LINE"
  nl -ba -w3 -s': ' "$F" | sed -n "${START_LINE},${END_LINE}p"

  printf "\n--- Hex/visible of lines %s..%s ---\n" "$START_LINE" "$END_LINE"
  sed -n "${START_LINE},${END_LINE}p" "$F" | nl -ba -w3 -s': ' | while read -r L; do
    LN=$(printf "%s" "$L" | cut -d: -f1)
    # get raw content of the line
    LINE_CONTENT=$(sed -n "${LN}p" "$F" || true)
    printf "\nLine %s text: %s\n" "$LN" "$LINE_CONTENT"
    printf "Line %s visible chars (cat -A):\n" "$LN"
    sed -n "${LN}p" "$F" | cat -A -v || true
    printf "Line %s as hex (xxd):\n" "$LN"
    sed -n "${LN}p" "$F" | xxd -g 1 -u || true

    # Now byte-by-byte table (index, hex, printable or escaped)
    printf "\nLine %s byte-by-byte:\n" "$LN"
    python3 - <<PY
import sys
F = "$F"
LN = $LN
try:
    with open(F, "rb") as fh:
        lines = fh.read().splitlines()
    if len(lines) < LN:
        print(f"(file has only {len(lines)} lines; requested line {LN})")
        sys.exit(0)
    b = lines[LN-1]
    # Print header
    print(f"{'Idx':>4s} {'Hex':>6s} {'Dec':>4s} {'Char'}")
    for i, byte in enumerate(b, start=1):
        hexv = f"0x{byte:02X}"
        decv = str(byte)
        # Determine printable representation
        if 32 <= byte < 127:
            ch = chr(byte)
            # escape spaces to make them visible
            if ch == ' ':
                ch_disp = "' '"
            else:
                ch_disp = ch
        else:
            ch_disp = f"\\x{byte:02X}"
        print(f"{i:4d} {hexv:>6s} {decv:>4s} {ch_disp}")
    # Attempt to decode full line as UTF-8 and print it
    try:
        s = b.decode("utf-8")
        print("\\nDecoded (utf-8):")
        print(s)
    except Exception as e:
        print("\\nDecoded (utf-8) failed:", e)
except Exception as e:
    print('ERROR reading file in python diagnostic:', e)
PY
  done

done

printf "\nDiagnosis complete.\n"
