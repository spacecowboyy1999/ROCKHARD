#!/usr/bin/env bash
# Sets up real Papyrus compilation in a fresh Linux session via Wine.
#
# The container is ephemeral, so this has to be re-run each session. Verified
# working: Wine 9.0 from Ubuntu noble executes Windows binaries here.
#
# Needs, dropped somewhere findable:
#   - the CK's "Papyrus Compiler" folder (PapyrusCompiler.exe + its DLLs)
#   - reference/  (extracted Base.zip; supplies Institute_Papyrus_Flags.flg)
set -euo pipefail

WINE=/usr/lib/wine/wine64          # the package does NOT put wine on PATH
export WINEPREFIX=${WINEPREFIX:-/tmp/wineprefix}
export WINEDEBUG=-all
export HOME=${HOME:-/root}

if [ ! -x "$WINE" ]; then
	echo "==> installing wine64"
	apt-get update -q
	DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends wine64
fi

echo "==> $("$WINE" --version)"
"$WINE" cmd /c "echo wine ok" >/dev/null 2>&1 || { echo "wine cannot execute"; exit 1; }

# PapyrusCompiler.exe may be a .NET binary. If it dies on startup with a
# missing-runtime error, install mono and retry:
#   apt-get install -y mono-complete
# If it turns out to be 32-bit, enable i386 first:
#   dpkg --add-architecture i386 && apt-get update && apt-get install -y wine32

COMPILER=${1:-}
if [ -z "$COMPILER" ]; then
	echo "usage: $0 /path/to/PapyrusCompiler.exe [file.psc ...]"
	exit 0
fi

shift || true
FLAGS_DIR="$(cd "$(dirname "$0")/../reference" && pwd)"
SRC_DIR="$(cd "$(dirname "$0")/../Scripts/Source/User" && pwd)"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/build"
mkdir -p "$OUT_DIR"

for f in "$@"; do
	echo "==> compiling $(basename "$f")"
	"$WINE" "$COMPILER" "$f" \
		-import="$SRC_DIR;$FLAGS_DIR;$FLAGS_DIR/extenders" \
		-flags=Institute_Papyrus_Flags.flg \
		-output="$OUT_DIR" \
		2>&1 | grep -v "^wine:" || true
done
