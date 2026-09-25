#!/usr/bin/env python3
"""Report dependency patch-removal readiness using actual pinned source bytes."""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("source_verifier", Path(__file__).with_name("verify-shared-features-source.py"))
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


def audit(root, source_packages):
    identity = VERIFIER.contract(root)
    blockers = []
    dependencies = None
    try:
        dependencies = VERIFIER.verify_dependency_graph(root, source_packages)
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        blockers.append(str(error))
    wiring = subprocess.run(["bash", str(root / "scripts/deps/check-shared-features-fix-wiring.sh"), str(root)],
                            capture_output=True, text=True)
    if wiring.returncode:
        blockers.append("Build source verification wiring failed: " + wiring.stderr.strip())
    # Retired entry points must themselves be read-only, so older callers cannot
    # silently reinstate post-resolution patching.
    compatibility = '''#!/usr/bin/env bash
set -euo pipefail

# Compatibility entry point. Resolved dependency sources are immutable.
ROOT="${1:-$(pwd)}"
exec python3 "$ROOT/scripts/deps/verify-shared-features-source.py" "$ROOT"
'''
    mutation = wiring.returncode != 0
    for name in ["scripts/spm-shared-features-fixes.sh", "scripts/deps/prepare-native-crypto-checkout.sh",
                 "scripts/deps/apply-native-crypto-package-contract.sh", "scripts/deps/apply-native-crypto-modulemap-contract.sh"]:
        if (root / name).read_text() != compatibility:
            blockers.append(f"Retired mutation helper differs from the read-only compatibility contract: {name}")
            mutation = True
    templates = []
    for name in ["IrohaCrypto.module.modulemap", "IrohaCrypto-umbrella.h", "IrohaCrypto.linker-settings.swiftfrag"]:
        path = Path("scripts/deps/templates") / name
        templates.append({"name": name, "path": str(path), "sha256": hashlib.sha256((root / path).read_bytes()).hexdigest()})
    return {
        "schemaVersion": 1,
        "sharedFeaturesRevision": identity["revision"],
        "sharedFeaturesTree": identity["tree"],
        "reviewUrl": identity["reviewUrl"],
        "verifiedDependencies": dependencies,
        "mutatesResolvedCheckout": mutation,
        "exitCondition": "Pinned source contains every carried delta and builds verify its exact contents without patching resolved dependencies.",
        "removalReadiness": {
            "status": "blocked" if blockers else "ready",
            "requiredAction": "Keep all carriedDeltas in reviewed immutable source and retain read-only verification in every build path.",
            "verificationCommand": "bash scripts/deps/audit-shared-features-delta-report.sh --require-ready",
            "blockers": blockers,
            "requiredAbsentMarkersBeforeResolved": ["post-resolution dependency source mutation"],
        },
        "nativeCryptoTemplates": templates,
        "carriedDeltas": [{"id": name, "label": name, "evidence": identity["revision"]} for name in identity["carriedDeltas"]],
        "releaseQualified": False,
        "remainingReleaseRequirements": ["Independent review and protected-branch CI", "Final wallet source and distribution acceptance"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--write-report", type=Path)
    parser.add_argument("--require-ready", action="store_true")
    args = parser.parse_args()
    try:
        report = audit(args.root, Path(os.environ.get("SOURCE_PACKAGES_DIR", args.root / "SourcePackages")))
        if args.write_report:
            args.write_report.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode="w", dir=args.write_report.parent, delete=False) as output:
                json.dump(report, output, indent=2)
                output.write("\n")
                temporary = output.name
            os.replace(temporary, args.write_report)
        ready = report["removalReadiness"]["status"] == "ready"
        print(f"[shared-features-delta] revision={report['sharedFeaturesRevision']} removalReadiness={report['removalReadiness']['status']}")
        for blocker in report["removalReadiness"]["blockers"]:
            print(f"[shared-features-delta] {blocker}", file=sys.stderr)
        return 0 if ready else 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"[shared-features-delta] Rejected: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
