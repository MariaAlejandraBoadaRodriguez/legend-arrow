#!/usr/bin/env python3
"""Line coverage for GDScript logic (there is no maintained coverage tool for
Godot 4 GDScript, so this is a small source instrumenter).

How it works:
  1. Copies the project to a temp dir.
  2. In each target script, inserts `CovProbe.hit(file, line)` before every
     statement that starts a line inside a function body (same indentation).
     Not instrumented (so not counted): class-level declarations, func
     signatures, `elif`/`else` lines, `match` pattern lines, continuation lines
     inside brackets, comments and blank lines.
  3. Runs the full GUT suite in the copy with a post-run hook that dumps hits.
  4. Reports executed / instrumented statement lines per file and per group.

    GODOT=/path/to/godot python3 tools/coverage.py [out_dir]

Exit code 1 if a group is below its target (brief §4: 90% puzzle/solver/
progression, 80% save/reward) or the tests fail.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GODOT = os.environ.get("GODOT", "godot")

GROUPS = {
    "puzzle, solver and progression (target 90%)": (90.0, [
        "scripts/core/arrow_path.gd", "scripts/core/puzzle_board.gd", "scripts/core/puzzle_session.gd",
        "scripts/core/puzzle_solver.gd", "scripts/core/level_validator.gd", "scripts/core/level_generator.gd",
        "scripts/core/level_data.gd", "scripts/core/deterministic_rng.gd", "scripts/core/campaign.gd",
        "scripts/core/progression.gd",
    ]),
    "save and reward handling (target 80%)": (80.0, [
        "scripts/core/save_repository.gd", "scripts/core/save_schema.gd", "scripts/services/ad_service.gd",
        "scripts/services/interstitial_policy.gd", "scripts/services/remote_config.gd",
    ]),
}

PROBE = """class_name CovProbe
## Coverage probe (inserted by tools/coverage.py; never part of the game).
static var hits: Dictionary = {}


static func hit(f: int, l: int) -> void:
	hits[f * 100000 + l] = true
"""

HOOK = """extends GutHookScript


func run() -> void:
	var f := FileAccess.open("res://coverage_hits.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(CovProbe.hits.keys()))
	f.close()
"""

SKIP_START = re.compile(r"^(elif\b|else\b|func\b|static func\b|@|class_name\b|extends\b|signal\b|const\b|enum\b)")


def code_part(line):
    """Line without a trailing comment (quote-aware) and stripped."""
    out, quote = [], None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            out.append(c)
            if c == "\\":
                out.append(line[i + 1] if i + 1 < len(line) else "")
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out).rstrip()


def depth_delta(code):
    d, quote = 0, None
    i = 0
    while i < len(code):
        c = code[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in "([{":
            d += 1
        elif c in ")]}":
            d -= 1
        i += 1
    return d


def indent_of(line):
    return len(line) - len(line.lstrip("\t"))


def instrument(src, fid):
    lines = src.split("\n")
    out, points = [], []
    depth = 0
    continued = False
    func_indent = None
    match_stack = []  # [match_indent, pattern_indent or None]
    for n, raw in enumerate(lines, start=1):
        code = code_part(raw)
        stripped = code.strip()
        starts_statement = depth == 0 and not continued and stripped != ""
        ind = indent_of(raw)
        if starts_statement:
            if re.match(r"^(static )?func\b", stripped):
                func_indent = ind
            elif func_indent is not None and ind <= func_indent:
                func_indent = None  # back at class level
            while match_stack and ind <= match_stack[-1][0]:
                match_stack.pop()
            is_pattern = False
            if match_stack:
                top = match_stack[-1]
                if top[1] is None:
                    top[1] = ind
                is_pattern = ind == top[1]
            body = func_indent is not None and ind > func_indent
            if body and not is_pattern and not SKIP_START.match(stripped):
                out.append(raw[:ind] + "CovProbe.hit(%d, %d)" % (fid, n))
                points.append(n)
            if re.match(r"^match\b.*:$", stripped):
                match_stack.append([ind, None])
        out.append(raw)
        depth = max(0, depth + depth_delta(code))
        continued = code.endswith("\\")
    return "\n".join(out), points


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "coverage"))
    os.makedirs(out_dir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="legend_cov_")
    try:
        shutil.copytree(ROOT, work, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".git", "build", ".godot", "android", "docs"))
        files = [f for _, (_, fs) in GROUPS.items() for f in fs]
        points = {}
        for fid, rel in enumerate(files):
            p = os.path.join(work, rel)
            src = open(p).read()
            new, pts = instrument(src, fid)
            open(p, "w").write(new)
            points[rel] = pts
        open(os.path.join(work, "cov_probe.gd"), "w").write(PROBE)
        open(os.path.join(work, "cov_hook.gd"), "w").write(HOOK)
        imp = subprocess.run([GODOT, "--headless", "--path", work, "--import"], capture_output=True, text=True)
        gut = subprocess.run([GODOT, "--headless", "--path", work, "-s", "res://addons/gut/gut_cmdln.gd",
                              "-gconfig=res://.gutconfig.json", "-gpost_run_script=res://cov_hook.gd"],
                             capture_output=True, text=True)
        open(os.path.join(out_dir, "gut_instrumented.log"), "w").write(imp.stdout + imp.stderr + gut.stdout + gut.stderr)
        errors = [l for l in (gut.stdout + gut.stderr).splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
        hits_path = os.path.join(work, "coverage_hits.json")
        if gut.returncode != 0 or errors or not os.path.exists(hits_path):
            print("coverage: instrumented test run failed (rc=%d)" % gut.returncode)
            print("\n".join(errors[:20]) or (gut.stdout + gut.stderr)[-3000:])
            return 1
        hit = {int(k) for k in json.load(open(hits_path))}
    finally:
        shutil.rmtree(work, ignore_errors=True)

    report = {"method": "statement-line instrumentation (tools/coverage.py)", "files": {}, "groups": {}}
    rows, ok = [], True
    for gname, (target, fs) in GROUPS.items():
        g_total = g_hit = 0
        for rel in fs:
            fid = files.index(rel)
            pts = points[rel]
            covered = [n for n in pts if fid * 100000 + n in hit]
            missed = [n for n in pts if fid * 100000 + n not in hit]
            pct = 100.0 * len(covered) / max(1, len(pts))
            report["files"][rel] = {"statements": len(pts), "covered": len(covered), "percent": round(pct, 1), "missed_lines": missed}
            rows.append((rel, len(pts), len(covered), pct))
            g_total += len(pts)
            g_hit += len(covered)
        gpct = 100.0 * g_hit / max(1, g_total)
        passed = gpct >= target
        ok &= passed
        report["groups"][gname] = {"statements": g_total, "covered": g_hit, "percent": round(gpct, 1), "target": target, "pass": passed}
    json.dump(report, open(os.path.join(out_dir, "coverage.json"), "w"), indent=2)
    with open(os.path.join(out_dir, "coverage.md"), "w") as md:
        md.write("| File | Statements | Covered | % |\n|---|---:|---:|---:|\n")
        for rel, t, c, p in rows:
            md.write("| `%s` | %d | %d | %.1f |\n" % (rel, t, c, p))
        md.write("\n| Group | Covered / statements | % | Target | Result |\n|---|---:|---:|---:|---|\n")
        for g, v in report["groups"].items():
            md.write("| %s | %d / %d | %.1f | %.0f | %s |\n" % (g, v["covered"], v["statements"], v["percent"], v["target"], "PASS" if v["pass"] else "FAIL"))
    print(open(os.path.join(out_dir, "coverage.md")).read())
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
