#!/usr/bin/env python3
"""Canonical roster (owner decision D-41): parses docs/ART_PROMPTS.md into
data/roster.json and checks it. Stdlib only.

  python3 tools/roster.py            # write data/roster.json
  python3 tools/roster.py --strings  # world/dragon names + lore into locales/strings.csv
  python3 tools/roster.py --check    # fail if data/roster.json is stale or
                                     # the roster / raw images disagree

ids, names, world order and file names are taken verbatim; world order is
difficulty order. A world's "tone" (the atmosphere thumbnail colours) is
derived from its colour rule band: muted (1-2), vivid (3-4), jewel (5-7),
legendary (8-10).
"""
import json
import os
import re
import sys

SRC = "docs/ART_PROMPTS.md"
OUT = "data/roster.json"
RAW = "assets/creatures/raw"

WORLD_RE = re.compile(r"^## World (\d+) — (.+?)\s*$")
ROW_RE = re.compile(r"^\| (\d{3}) \| ([a-z0-9_]+) \| ([^|]+?) \| ([^|]+?) \| (.+?) \|\s*$")


def tone(world_no):
    return "muted" if world_no <= 2 else "vivid" if world_no <= 4 else "jewel" if world_no <= 7 else "legendary"


def parse(path=SRC):
    worlds, dragons, current = [], [], None
    for line in open(path, encoding="utf-8"):
        m = WORLD_RE.match(line)
        if m:
            current = {"id": "w%02d" % int(m.group(1)), "number": int(m.group(1)), "name": m.group(2).strip(),
                       "tone": tone(int(m.group(1))), "dragons": []}
            worlds.append(current)
            continue
        m = ROW_RE.match(line)
        if m and current is not None:
            num, did, name, file, desc = m.groups()
            dragons.append({"number": int(num), "id": did, "name": name.strip(), "file": file.strip(),
                            "world": current["id"], "description": desc.strip()})
            current["dragons"].append(did)
    return {"source": SRC, "worlds": worlds, "dragons": dragons}


def problems(r):
    out = []
    if len(r["worlds"]) != 10:
        out.append(f"expected 10 worlds, found {len(r['worlds'])}")
    for i, w in enumerate(r["worlds"], 1):
        if w["number"] != i:
            out.append(f"world order broken at {w['id']}")
        if len(w["dragons"]) != 10:
            out.append(f"{w['id']} has {len(w['dragons'])} dragons")
    ids = [d["id"] for d in r["dragons"]]
    if len(ids) != 100 or len(set(ids)) != 100:
        out.append(f"expected 100 unique dragon ids, found {len(ids)} ({len(set(ids))} unique)")
    for i, d in enumerate(r["dragons"], 1):
        if d["number"] != i:
            out.append(f"dragon numbering broken at {d['id']}")
        if d["file"] != d["id"] + ".png":
            out.append(f"{d['id']}: file name {d['file']} does not match the id")
    return out


def main():
    if "--strings" in sys.argv:
        write_strings()
        return 0
    r = parse()
    errs = problems(r)
    text = json.dumps(r, indent=1, ensure_ascii=False) + "\n"
    if "--check" in sys.argv:
        if not os.path.exists(OUT) or open(OUT, encoding="utf-8").read() != text:
            errs.append(f"{OUT} is stale: run python3 tools/roster.py")
        if os.path.isdir(RAW):
            files = {f for f in os.listdir(RAW) if f.endswith(".png")}
            want = {d["file"] for d in r["dragons"]}
            for f in sorted(files - want):
                errs.append(f"{RAW}/{f}: not in the roster")
    else:
        if not errs:
            with open(OUT, "w", encoding="utf-8") as fh:
                fh.write(text)
    for e in errs:
        print("FAIL", e)
    print(f"roster: {'PASS' if not errs else 'FAIL'} ({len(r['worlds'])} worlds, {len(r['dragons'])} dragons)")
    return 0 if not errs else 1


def write_strings(path="locales/strings.csv"):
    """Replaces the WORLD_* / CREATURE_* / REALM_* rows of the string table
    with names and one-line lore from the roster (English only, D-41)."""
    import csv
    r = parse()
    rows = list(csv.reader(open(path, newline="", encoding="utf-8")))
    keep = [row for row in rows if row and not row[0].startswith(("CREATURE_", "REALM_", "WORLD_"))]
    for w in r["worlds"]:
        keep.append(["WORLD_%s" % w["id"].upper(), w["name"]])
    for d in r["dragons"]:
        lore = re.sub(r"(,\s*|\s+)(slight low angle,\s*)?(majestic\s+)?(in\s+)?(three-quarter|side|front)\s+view\s*$", "",
                      d["description"].strip().rstrip("."))
        lore = re.sub(r",?\s+(standing|walking|crouched|prowling|rearing|gliding)?\s*(calmly|proudly|firmly|forward|low and alert)?\s*$", "", lore) if lore.endswith((" in", " and")) else lore
        lore = re.sub(r",\s*(majestic view|epic(\s+\w+)*|[\w\s-]*\bview)\s*$", "", lore)
        lore = lore[0].upper() + lore[1:] + "."
        keep.append(["CREATURE_%s" % d["id"].upper(), d["name"]])
        keep.append(["CREATURE_%s_LORE" % d["id"].upper(), lore])
    with open(path, "w", newline="", encoding="utf-8") as fh:
        csv.writer(fh, lineterminator="\n").writerows(keep)
    print(f"roster: wrote {len(r['worlds'])} world and {len(r['dragons'])} dragon names to {path}")


if __name__ == "__main__":
    sys.exit(main())
