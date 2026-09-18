#!/usr/bin/env bash
# Compiles ROCKHARD's Papyrus scripts to .pex on Linux. No Windows needed.
#
# Two stages, because Bethesda's toolchain is split across two binary formats:
#   1. PapyrusCompiler.exe  - 32-bit .NET  -> runs under mono
#   2. PapyrusAssembler.exe - native win32 -> runs under 32-bit wine
# So the compiler runs with -asmonly to emit .pas, and wine assembles to .pex.
#
# Gotcha worth remembering: the assembler takes the object name WITHOUT the
# .pas extension, resolved from the cwd. Passing "Name.pas" or a Z:\ path both
# fail with "Cannot open store for class".
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Scripts/Source/User"
REF="$ROOT/reference"
OUT="$ROOT/build"
CC="$ROOT/tools/PapyrusCompiler/PapyrusCompiler.exe"
ASM="$ROOT/tools/PapyrusCompiler/PapyrusAssembler.exe"
WINE=/usr/lib/wine/wine                      # 32-bit loader; wine64 can't run the assembler
export WINEDEBUG=-all WINEPREFIX=${WINEPREFIX:-/tmp/wp32} HOME=${HOME:-/root}

[ -f "$CC" ] || { echo "missing $CC - see tools/README.md"; exit 1; }
mkdir -p "$OUT"

# Import order matters: F4SE ships FULL replacements of vanilla Actor.psc,
# ObjectReference.psc etc (vanilla + its own additions), so it must come first
# or its functions won't resolve.
imports_for() {
	case "$1" in
		*_F4SE.psc) echo "$REF/f4se;$REF;$SRC" ;;
		*_GOE.psc)  echo "$REF;$REF/extenders;$SRC" ;;
		*)          echo "$REF;$SRC" ;;
	esac
}

fail=0
cd "$SRC"
for f in "${@:-}"; do :; done
FILES=("$@"); [ ${#FILES[@]} -eq 0 ] && FILES=(*.psc)

for f in "${FILES[@]}"; do
	f="$(basename "$f")"
	printf "%-44s " "$f"
	out=$(mono "$CC" "$f" -import="$(imports_for "$f")" \
		-flags=Institute_Papyrus_Flags.flg -output="$OUT" -asmonly 2>&1)
	if ! echo "$out" | grep -q "0 failed"; then
		echo "COMPILE FAILED"
		echo "$out" | grep -E "\.psc\([0-9]+,[0-9]+\)" | sed 's/^/    /'
		fail=1; continue
	fi
	n="${f%.psc}"
	( cd "$OUT" && timeout 120 "$WINE" "$ASM" "$n" >/dev/null 2>&1 )
	if [ -f "$OUT/$n.pex" ]; then
		echo "OK -> $n.pex ($(stat -c%s "$OUT/$n.pex") bytes)"
	else
		echo "ASSEMBLE FAILED"; fail=1
	fi
done
exit $fail
