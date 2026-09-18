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

## `build.sh` — real compilation on Linux

Bethesda's toolchain runs here. `tools/build.sh` compiles the scripts to real
`.pex`, verified by magic bytes (`FA57C0DE`) and a disassembly round-trip.

```
tools/build.sh                                  # everything
tools/build.sh RX_VendingMachineScript.psc      # one file
```

### How it works

The toolchain is split across two binary formats, which is why one runtime
isn't enough:

| Stage | Binary | Format | Runtime |
|---|---|---|---|
| compile `.psc` → `.pas` | `PapyrusCompiler.exe` 2.8.0.4 | 32-bit .NET | `mono` |
| assemble `.pas` → `.pex` | `PapyrusAssembler.exe` 2.7.0.2 | native win32 | 32-bit `wine` |

So the compiler runs under mono with `-asmonly`, and wine assembles the result.
`wine64` alone cannot run the assembler — Ubuntu's wine 9.0 has no working wow64,
so the i386 loader at `/usr/lib/wine/wine` is required.

### Environment setup (ephemeral container — redo each session)

```
apt-get update
apt-get install -y --no-install-recommends mono-complete wine64
dpkg --add-architecture i386 && apt-get update
apt-get install -y --no-install-recommends libgd3:i386 libgphoto2-6t64:i386 wine32:i386
```

The i386 deps are listed explicitly because `wine32:i386` alone fails to resolve
them. The wine packages do **not** put anything on `PATH`.

### Gotchas worth keeping

- The **assembler takes the object name without `.pas`**, resolved from the cwd.
  `Name.pas` and `Z:\path\Name.pas` both fail with "Cannot open store for class".
- **Import order matters.** F4SE ships *full replacements* of vanilla scripts
  (its `Actor.psc` is vanilla's 1101 lines plus its own), so `reference/f4se`
  must precede `reference` or its additions won't resolve.
- `Institute_Papyrus_Flags.flg` ships inside the CK's `Base.zip`.
- A nested `{ }` inside a Papyrus doc comment — e.g. documenting a message's
  `{0}` token — silently terminates the comment and corrupts everything after
  it. Only the real compiler catches this.

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
