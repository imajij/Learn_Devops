#!/usr/bin/env python3
"""Security gate: reads the scanner reports and decides PASS / FAIL.

usage: python security/gate.py <reports-dir> [policy.json]

Fails closed: a missing or unreadable report counts as a failure.
Writes a Markdown table to $GITHUB_STEP_SUMMARY when it is set.
"""
import json
import os
import re
import sys

CONF_RANK = {"LOW": 1, "MEDIUM": 2, "HIGH": 3}


def redact(text):
    """Bandit quotes suspected passwords in issue_text - never print them."""
    return re.sub(r"'[^']{8,}'", "'<redacted>'", text)


def load(path):
    with open(path) as fh:
        return json.load(fh)


def check_sast(report, pol):
    blocking, other = [], 0
    for r in report.get("results", []):
        if (r["issue_severity"] in pol["block_severities"]
                and CONF_RANK[r["issue_confidence"]] >= CONF_RANK[pol["min_confidence"]]):
            blocking.append(f'{r["test_id"]} {r["issue_severity"]} {r["filename"]}:{r["line_number"]} '
                            f'{redact(r["issue_text"])[:70]}')
        else:
            other += 1
    return blocking, other


def check_sca(report, pol):
    blocking, other = [], 0
    for dep in report.get("dependencies", []):
        for v in dep.get("vulns", []):
            fix = ",".join(v.get("fix_versions", [])) or "none"
            if pol["block_only_if_fix_available"] and fix == "none":
                other += 1
                continue
            blocking.append(f'{dep["name"]}=={dep["version"]} {v["id"]} (fixed in {fix})')
    return blocking, other


def check_secrets(report, pol):
    findings = [f'{f["RuleID"]} in {f["File"]}:{f["StartLine"]} (value redacted)' for f in report or []]
    return (findings if len(findings) > pol["max_findings"] else []), 0


def check_image(report, pol):
    blocking, other = [], 0
    for res in report.get("Results", []):
        for v in res.get("Vulnerabilities") or []:
            fixed = v.get("FixedVersion")
            if v["Severity"] in pol["block_severities"] and (fixed or not pol["block_only_if_fix_available"]):
                blocking.append(f'{v["VulnerabilityID"]} {v["Severity"]} {v["PkgName"]} '
                                f'{v["InstalledVersion"]} -> {fixed or "no fix"}')
            else:
                other += 1
    return blocking, other


CHECKS = [
    ("SAST", "sast", "bandit.json", check_sast),
    ("SCA", "sca", "pip-audit.json", check_sca),
    ("Secret scan", "secrets", "gitleaks.json", check_secrets),
    ("Image scan", "image", "trivy-image.json", check_image),
]


def main():
    reports = sys.argv[1] if len(sys.argv) > 1 else "reports"
    policy = load(sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "gate-policy.json"))
    rows, failed = [], False
    for label, key, fname, fn in CHECKS:
        path = os.path.join(reports, fname)
        try:
            blocking, other = fn(load(path), policy[key])
        except (OSError, ValueError, KeyError) as err:
            blocking, other = [f"report missing/unreadable: {path} ({err})"], 0
        status = "FAIL" if blocking else "PASS"
        failed |= bool(blocking)
        rows.append((label, policy[key]["tool"], status, len(blocking), other))
        print(f"[{status}] {label:<11} ({policy[key]['tool']}): {len(blocking)} blocking, {other} below threshold")
        for item in blocking[:15]:
            print(f"         - {item}")
        if len(blocking) > 15:
            print(f"         ... and {len(blocking) - 15} more")
    verdict = "FAIL - pipeline stopped, image will NOT be pushed or deployed" if failed else \
        "PASS - image may be pushed and deployed"
    print(f"\nSECURITY GATE: {verdict}")
    summary = os.getenv("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as fh:
            fh.write("## Security gate\n\n| Check | Tool | Result | Blocking | Below threshold |\n|---|---|---|---|---|\n")
            for r in rows:
                fh.write("| " + " | ".join(str(c) for c in r) + " |\n")
            fh.write(f"\n**{verdict}**\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
