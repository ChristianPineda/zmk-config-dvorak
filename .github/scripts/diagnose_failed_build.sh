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
    LN=32
printf "\n--- Detalle byte-a-byte de la línea %s ---\n" "$LN"
# línea visible con caracteres especiales marcados
sed -n "${LN}p" "$F" | cat -A -v
# línea en hex
sed -n "${LN}p" "$F" | xxd -g 1 -u
# tabla index:byte(hex):printable (usa Python para mostrar index y valor de cada byte)
python3 - <<'PY'
import sys
F = sys.argv[1]
LN = int(sys.argv[2])
with open(F, "rb") as f:
    lines = f.read().splitlines()
if len(lines) < LN:
    print(f"El archivo tiene menos de {LN} líneas; total:", len(lines))
    sys.exit(0)
b = lines[LN-1]
print("Index : Byte(hex) : Char(if printable) / Escaped")
for i, c in enumerate(b, start=1):
    ch = chr(c) if 32 <= c < 127 else None
    disp = ch if ch is not None else f"\\x{c:02X}"
    print(f"{i:3d} : 0x{c:02X} : {disp}")
print("\nDecoded utf-8 attempt:")
try:
    print(b.decode("utf-8"))
except Exception as e:
    print("ERROR decoding utf-8:", e)
PY
  done
done
