#!/usr/bin/env python3
"""Papyrus API index over the vanilla + extender sources in reference/.

Answers "does this function exist and what's its exact signature" by reading the
real sources instead of guessing. Built after a guessed ObjectReference.Detach()
turned out not to exist.

  papyrus_api.py find <name>          declarations matching <name> (substring, any script)
  papyrus_api.py sig <Script.Func>    exact signature
  papyrus_api.py script <Script>      a script's whole function/event surface
  papyrus_api.py uses <Func>          how the vanilla scripts actually call it
  papyrus_api.py verify <file.psc>    flag every call in <file> with no declaration
  papyrus_api.py stats                what's indexed
"""
import re, os, sys, glob, collections

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "reference")

DECL = re.compile(
    r'^\s*(?P<ret>[\w:\[\]]+\s+)?(?P<kind>Function|Event)\s+(?P<name>\w+)\s*\((?P<args>[^)]*)\)',
    re.I)
SCRIPTLINE = re.compile(r'^\s*ScriptName\s+(\w+)(?:\s+extends\s+(\w+))?', re.I)

# Papyrus has three comment forms: ; to end of line, ;/ ... /; blocks, and
# { ... } doc strings. All three can contain prose that parses as a call.
BLOCK = re.compile(r';/.*?/;', re.S)
DOCSTR = re.compile(r'\{.*?\}', re.S)


def strip_comments(txt):
    """Blank out block and doc comments, preserving line numbering."""
    def blank(m):
        return re.sub(r'[^\n]', ' ', m.group(0))
    return DOCSTR.sub(blank, BLOCK.sub(blank, txt))

# Control-flow and declaration keywords that look like calls but aren't.
NOISE = {'if','elseif','while','return','endif','function','event','property',
         'int','float','bool','string','new','else','endwhile','endfunction',
         'endevent','state','endstate','import','scriptname','auto','const',
         'native','global','hidden','extends','as','is','length','struct'}


def load():
    """-> (decls, parents) where decls[name.lower()] = [(script, kind, signature)]"""
    decls, parents = collections.defaultdict(list), {}
    for path in glob.glob(os.path.join(ROOT, "**", "*.psc"), recursive=True):
        name = os.path.basename(path)[:-4]
        try:
            txt = open(path, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        m = SCRIPTLINE.search(txt)
        if m and m.group(2):
            parents[m.group(1).lower()] = m.group(2)
        txt = strip_comments(txt)
        for line in txt.splitlines():
            if line.lstrip().startswith(';'):
                continue
            d = DECL.match(line)
            if d:
                decls[d.group('name').lower()].append(
                    (name, d.group('kind'), line.strip()))
    return decls, parents


def chain(script, parents):
    """A script plus everything it inherits from."""
    out, cur, seen = [], script.lower(), set()
    while cur and cur not in seen:
        seen.add(cur)
        out.append(cur)
        cur = (parents.get(cur) or "").lower()
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__); return 1
    cmd, arg = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
    decls, parents = load()

    if cmd == "stats":
        files = len(glob.glob(os.path.join(ROOT, "**", "*.psc"), recursive=True))
        print(f"{files} source files, {len(decls)} distinct function/event names, "
              f"{sum(len(v) for v in decls.values())} declarations")

    elif cmd == "find":
        hits = [(n, e) for n, v in decls.items() if arg.lower() in n for e in v]
        for _, (s, k, sig) in sorted(hits)[:60]:
            print(f"  {s+'.':28s} {sig}")
        print(f"  -- {len(hits)} match(es)")

    elif cmd == "sig":
        script, _, fn = arg.rpartition(".")
        for s, k, sig in decls.get(fn.lower(), []):
            if not script or s.lower() in chain(script, parents) or s.lower() == script.lower():
                print(f"  {s}: {sig}")

    elif cmd == "script":
        for n, v in sorted(decls.items()):
            for s, k, sig in v:
                if s.lower() == arg.lower():
                    print(f"  {sig}")

    elif cmd == "uses":
        pat = re.compile(r'\.\s*' + re.escape(arg) + r'\s*\(', re.I)
        n = 0
        for path in glob.glob(os.path.join(ROOT, "**", "*.psc"), recursive=True):
            for i, line in enumerate(open(path, encoding="utf-8", errors="ignore"), 1):
                if pat.search(line) and not line.lstrip().startswith(';'):
                    print(f"  {os.path.basename(path)}:{i}: {line.strip()[:110]}")
                    n += 1
                    if n >= 25:
                        print("  -- truncated"); return 0

    elif cmd == "verify":
        txt = strip_comments(open(arg, encoding="utf-8", errors="ignore").read())
        local = {m.group('name').lower() for line in txt.splitlines()
                 if not line.lstrip().startswith(';')
                 for m in [DECL.match(line)] if m}
        # Functions inherited from the script this file extends.
        m = SCRIPTLINE.search(txt)
        inherited = set()
        if m and m.group(2):
            for anc in chain(m.group(2), parents):
                for n, v in decls.items():
                    if any(s.lower() == anc for s, _, _ in v):
                        inherited.add(n)
        unknown = []
        for i, line in enumerate(txt.splitlines(), 1):
            if line.lstrip().startswith(';'):
                continue
            code = line.split(';')[0]
            for cm in re.finditer(r'(?:(\w+)\s*\.\s*)?(\w+)\s*\(', code):
                fn = cm.group(2).lower()
                if fn in NOISE or fn in local or fn in inherited or fn in decls:
                    continue
                unknown.append((i, cm.group(0).rstrip('('), line.strip()))
        print(f"  {os.path.basename(arg)}")
        if not unknown:
            print("    all calls resolve against the indexed sources")
        for i, call, line in unknown:
            print(f"    line {i}: NO DECLARATION for '{call}'  |  {line[:80]}")
        return 1 if unknown else 0

    else:
        print(__doc__); return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
