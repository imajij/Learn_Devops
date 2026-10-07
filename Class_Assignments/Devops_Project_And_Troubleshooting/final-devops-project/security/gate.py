#!/usr/bin/env python3
"""Security gate: read every scanner report, apply gate-policy.json, exit 1 to block.

usage: python3 security/gate.py <reports-dir> security/gate-policy.json

The scanners in the pipeline only *report*. This script is the single place that
decides whether an image may be pushed and deployed.
"""
import json
import sys
from pathlib import Path


def load(path: Path):
    if not path.exists():
        return None
    return json.loads(path.read_text() or "{}")


def main(reports: Path, policy_file: Path) -> int:
    policy = json.loads(policy_file.read_text())
    failures, lines = [], []

    # SAST - Bandit
    p = policy["sast"]
    data = load(reports / p["report"])
    if data is None:
        failures.append("SAST report missing")
    else:
        hits = [r for r in data.get("results", []) if r["issue_severity"] in p["block_severities"]]
        lines.append(f"SAST    bandit     : {len(data.get('results', []))} findings, {len(hits)} blocking")
        for r in hits:
            lines.append(f"          {r['test_id']} {r['issue_severity']} {r['filename']}:{r['line_number']} {r['issue_text']}")
        if hits:
            failures.append(f"SAST: {len(hits)} blocking findings")

    # SCA - pip-audit (Python dependencies)
    p = policy["sca_py"]
    data = load(reports / p["report"])
    if data is None:
        failures.append("pip-audit report missing")
    else:
        vulnerable = [d for d in data.get("dependencies", []) if d.get("vulns")]
        lines.append(f"SCA     pip-audit  : {len(data.get('dependencies', []))} packages, {len(vulnerable)} vulnerable")
        for d in vulnerable:
            ids = ", ".join(v["id"] for v in d["vulns"])
            lines.append(f"          {d['name']}=={d['version']}: {ids}")
        if len(vulnerable) > p["max_vulnerable_packages"]:
            failures.append(f"SCA: {len(vulnerable)} vulnerable Python packages")

    # SCA - npm audit (frontend dependencies)
    p = policy["sca_js"]
    data = load(reports / p["report"])
    if data is None:
        failures.append("npm audit report missing")
    else:
        counts = data.get("metadata", {}).get("vulnerabilities", {})
        blocking = sum(counts.get(s, 0) for s in p["block_severities"])
        lines.append(f"SCA     npm audit  : {counts.get('total', 0)} advisories, {blocking} high/critical")
        if blocking:
            failures.append(f"SCA: {blocking} high/critical npm advisories")

    # Secrets - Gitleaks
    p = policy["secrets"]
    data = load(reports / p["report"])
    if data is None:
        failures.append("gitleaks report missing")
    else:
        lines.append(f"SECRETS gitleaks   : {len(data)} findings")
        for f in data:
            lines.append(f"          {f['RuleID']} {f['File']}:{f['StartLine']}")
        if len(data) > p["max_findings"]:
            failures.append(f"SECRETS: {len(data)} leaked secrets")

    # Container images - Trivy
    p = policy["images"]
    for name in p["reports"]:
        data = load(reports / name)
        if data is None:
            failures.append(f"{name} missing")
            continue
        vulns = [v for r in data.get("Results", []) for v in (r.get("Vulnerabilities") or [])
                 if v["Severity"] in p["block_severities"]]
        blocking = [v for v in vulns if v.get("FixedVersion") or not p["block_only_if_fix_available"]]
        lines.append(f"IMAGE   {name:19}: {len(vulns)} HIGH/CRITICAL, {len(blocking)} with a fix (blocking)")
        for v in blocking[:10]:
            lines.append(f"          {v['VulnerabilityID']} {v['Severity']} {v['PkgName']} {v['InstalledVersion']} -> {v['FixedVersion']}")
        if blocking:
            failures.append(f"IMAGE {name}: {len(blocking)} fixable HIGH/CRITICAL CVEs")

    print("\n".join(lines))
    print("-" * 60)
    if failures:
        print("SECURITY GATE: FAILED")
        for f in failures:
            print(f"  x {f}")
        return 1
    print("SECURITY GATE: PASSED - image may be pushed and deployed")
    return 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]), Path(sys.argv[2])))
