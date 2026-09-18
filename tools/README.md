# tools

## `papyrus_api.py`

Looks up Papyrus functions in the real sources instead of going from memory.

Existed because a guessed `ObjectReference.Detach()` call — which looks
perfectly reasonable next to the real `AttachTo()` — turned out not to exist at
all, and would have failed at compile time.

```
python3 tools/papyrus_api.py stats                  what's indexed
python3 tools/papyrus_api.py find <name>            declarations matching a name
python3 tools/papyrus_api.py sig ObjectReference.PlaceAtNode
python3 tools/papyrus_api.py script Weapon          a script's whole surface
python3 tools/papyrus_api.py uses GetEquippedWeapon how vanilla actually calls it
python3 tools/papyrus_api.py verify <file.psc>      flag calls with no declaration
```

`verify` is the useful one before a compile: it reports any call in your script
that has no declaration anywhere in the indexed sources.

## Rebuilding the index

It reads `reference/`, which is **gitignored** — those are Bethesda's and
LarannKiar's sources, not ours to redistribute. The directory is empty in a
fresh clone, so rebuild it locally:

```
unzip Base.zip -d reference/                    # CK's Scripts/Source/Base
mkdir -p reference/extenders                    # optional extender sources
cp GardenOfEden*.psc F4SE.psc reference/extenders/
```

Coverage is whatever you put there. Without `reference/extenders`, every GOE
call in the `_GOE` variant reports as undeclared — that's the index being
incomplete, not the script being wrong.
