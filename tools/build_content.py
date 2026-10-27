#!/usr/bin/env python3
"""Builds every creature level: silhouette mask -> generated, validated level.

Run from the repo root (needs xvfb-run for the mask render):
    GODOT=/path/to/godot python3 tools/build_content.py [creature_id ...]

Deterministic: the plan below fixes grid sizes, arrow counts and seed ranges.
If a silhouette has too few cells for the arrow count, the grid grows by one
column and row and the attempt repeats (recorded in the output).
"""
import os
import subprocess
import sys

GODOT = os.environ.get("GODOT", "godot")

# creature, slot, width, height, arrows, difficulty, max_len, min_depth
PLAN = [
    ("moon_owl", 1, 8, 10, 7, "easy", 4, 2),
    ("moon_owl", 2, 9, 11, 9, "easy", 4, 3),
    ("antler_fox", 1, 10, 9, 9, "easy", 4, 3),
    ("antler_fox", 2, 11, 10, 11, "easy", 4, 3),
    ("basilisk", 1, 11, 8, 10, "easy", 4, 3),
    ("basilisk", 2, 12, 9, 12, "easy", 4, 3),
    ("wyvern", 1, 11, 10, 14, "medium", 4, 3),
    ("wyvern", 2, 12, 11, 16, "medium", 4, 4),
    ("arctic_drake", 1, 12, 11, 16, "medium", 4, 4),
    ("arctic_drake", 2, 12, 12, 18, "medium", 4, 4),
    ("griffin", 1, 12, 11, 17, "medium", 4, 4),
    ("griffin", 2, 12, 12, 20, "medium", 4, 4),
    ("cloud_serpent", 1, 12, 12, 18, "medium", 4, 4),
    ("cloud_serpent", 2, 12, 13, 21, "medium", 4, 4),
    ("stone_wyrm", 1, 11, 13, 21, "medium", 4, 4),
    ("stone_wyrm", 2, 12, 14, 24, "medium", 4, 5),
    ("unicorn", 1, 12, 13, 25, "hard", 4, 5),
    ("unicorn", 2, 12, 14, 28, "hard", 4, 5),
    ("phoenix", 1, 12, 14, 28, "hard", 4, 5),
    ("phoenix", 2, 13, 15, 31, "hard", 4, 5),
    ("ancient_dragon", 1, 13, 15, 32, "hard", 4, 5),
    ("ancient_dragon", 2, 14, 16, 36, "hard", 4, 6),
]
MAX_GROW = 4
# Thin bodies get their silhouette thickened (see make_mask.gd).
DILATE = {"cloud_serpent": 1, "stone_wyrm": 1, "phoenix": 1}


def run(args, render=False):
    cmd = [GODOT, "--path", "."]
    if render:
        cmd = ["xvfb-run", "-a"] + cmd + ["--rendering-driver", "opengl3", "--audio-driver", "Dummy"]
    else:
        cmd += ["--headless"]
    return subprocess.run(cmd + args, capture_output=True, text=True)


def main(only):
    for cid, slot, w, h, n, diff, max_len, depth in PLAN:
        if only and cid not in only:
            continue
        for grow in range(MAX_GROW + 1):
            gw, gh = w + grow, h + grow
            m = run(["-s", "res://tools/make_mask.gd", "--", cid, str(slot), str(gw), str(gh), "0.3", str(DILATE.get(cid, 0))], render=True)
            if m.returncode != 0:
                sys.exit(f"mask failed for {cid}/{slot}:\n{m.stdout}\n{m.stderr}")
            g = run(["-s", "res://tools/generate_level.gd", "--", "--creature", cid, "--slot", str(slot),
                     "--arrows", str(n), "--difficulty", diff, "--max-len", str(max_len),
                     "--min-depth", str(depth), "--seeds", "1:250"])
            if g.returncode == 0:
                summary = [l for l in g.stdout.splitlines() if l.startswith("coverage=")]
                print(f"{cid}_{slot}: {gw}x{gh} {n} arrows {diff} {summary[0] if summary else ''}")
                break
            print(f"{cid}_{slot}: {gw}x{gh} failed, growing grid")
        else:
            sys.exit(f"could not build {cid}_{slot}")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
