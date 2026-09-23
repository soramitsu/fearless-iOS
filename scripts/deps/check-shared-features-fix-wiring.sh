#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"
for source in scripts/test-matrix.sh scripts/dev-setup.sh scripts/ci/bootstrap.sh scripts/ci/run-pr.sh .github/workflows/codecov.yml fearless.xcodeproj/project.pbxproj; do
  file="$ROOT/$source"
  if ! grep -Fq 'scripts/deps/verify-shared-features-source.py' "$file"; then
    echo "[check-shared-features-fix-wiring] Missing immutable source verification: $source" >&2
    exit 1
  fi
  if grep -Eq 'scripts/(spm-shared-features-fixes|deps/(prepare-native-crypto-checkout|apply-native-crypto-(package|modulemap)-contract))\.sh' "$file"; then
    echo "[check-shared-features-fix-wiring] Retired dependency mutation helper still wired: $source" >&2
    exit 1
  fi
  if grep 'verify-shared-features-source.py' "$file" | grep -Eq '\|\|[[:space:]]*true'; then
    echo "[check-shared-features-fix-wiring] Optional source verification: $source" >&2
    exit 1
  fi
done
echo "[check-shared-features-fix-wiring] OK"
