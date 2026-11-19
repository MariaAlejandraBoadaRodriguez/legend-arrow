#!/usr/bin/env python3
"""Fails if a UI string key used by the game is missing from
locales/strings.csv (a missing key shows on screen as the raw KEY_NAME).
Keys = ALL-CAPS string literals in scripts/**/*.gd plus every *_key value in
data/**/*.json. Stdlib only.   python3 tools/check_strings.py
"""
import csv
import json
import os
import re
import sys

NOT_KEYS = {"FAIL", "PASS", "SFX"}   # literals that are not translation keys
LIT = re.compile(r'"([A-Z][A-Z0-9_]{2,})"')


def main():
    keys = {r[0] for r in csv.reader(open("locales/strings.csv", encoding="utf-8")) if r}
    missing = {}
    for dp, _, fn in os.walk("scripts"):
        for f in fn:
            if f.endswith(".gd"):
                for i, line in enumerate(open(os.path.join(dp, f), encoding="utf-8"), 1):
                    for k in LIT.findall(line):
                        if k not in keys and k not in NOT_KEYS:
                            missing.setdefault(k, f"{os.path.join(dp, f)}:{i}")

    def walk(v, where):
        if isinstance(v, dict):
            for k2, v2 in v.items():
                if k2.endswith("_key") and isinstance(v2, str) and v2 and v2 not in keys:
                    missing.setdefault(v2, where)
                walk(v2, where)
        elif isinstance(v, list):
            for x in v:
                walk(x, where)
    for dp, _, fn in os.walk("data"):
        for f in fn:
            if f.endswith(".json"):
                walk(json.load(open(os.path.join(dp, f), encoding="utf-8")), os.path.join(dp, f))
    for k, w in sorted(missing.items()):
        print(f"FAIL missing string key {k} (used at {w})")
    print(f"strings: {'PASS' if not missing else 'FAIL'} ({len(keys)} keys, {len(missing)} missing)")
    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
