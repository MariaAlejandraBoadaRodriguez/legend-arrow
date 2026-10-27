#!/usr/bin/env python3
"""Gate on a GUT JUnit report.

Fails (exit 1) when the report is missing, has zero tests (empty discovery),
fewer tests than --min-tests, or any failure, error, skipped/pending or risky
(assertion-free) test. Prints a one-line machine-readable summary.
"""
import argparse
import json
import sys
import xml.etree.ElementTree as ET


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--min-tests", type=int, default=1)
    ap.add_argument("--summary-json", default="")
    ap.add_argument("--expect-scripts", nargs="*", default=[],
                    help="test script paths (res://...) that must each report >= 1 test")
    args = ap.parse_args()

    try:
        root = ET.parse(args.report).getroot()
    except (OSError, ET.ParseError) as exc:
        print(f"check_junit: cannot read report {args.report}: {exc}", file=sys.stderr)
        return 1

    cases = root.findall(".//testcase")
    failed, skipped, problems = [], [], []
    for case in cases:
        name = f"{case.get('classname', '')}::{case.get('name', '')}"
        if case.find("failure") is not None or case.find("error") is not None:
            failed.append(name)
        elif case.find("skipped") is not None:
            skipped.append(name)
        if int(case.get("assertions", "1") or 0) == 0 and case.find("skipped") is None:
            problems.append(name)

    summary = {
        "report": args.report,
        "discovered": len(cases),
        "failed": len(failed),
        "skipped_or_pending": len(skipped),
        "without_assertions": len(problems),
        "passed": len(cases) - len(failed) - len(skipped),
    }
    print("check_junit: " + json.dumps(summary))
    if args.summary_json:
        with open(args.summary_json, "w", encoding="utf-8") as fh:
            json.dump(summary, fh, indent=2)

    ok = True
    reported = {}
    for suite in root.findall(".//testsuite"):
        reported[suite.get("name", "")] = int(suite.get("tests", "0") or 0)
    for script in args.expect_scripts:
        key = script.replace("res://", "")
        if reported.get(key, 0) == 0:
            print(f"check_junit: FAIL test script reported no tests (load error?): {script}", file=sys.stderr)
            ok = False
    if len(cases) == 0:
        print("check_junit: FAIL empty test discovery", file=sys.stderr)
        ok = False
    elif len(cases) < args.min_tests:
        print(f"check_junit: FAIL only {len(cases)} tests discovered, expected >= {args.min_tests}", file=sys.stderr)
        ok = False
    for label, names in (("failed", failed), ("skipped/pending", skipped), ("no assertions", problems)):
        for n in names:
            print(f"check_junit: FAIL {label}: {n}", file=sys.stderr)
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
