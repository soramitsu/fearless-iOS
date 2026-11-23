#!/usr/bin/env bash
# Builds and tests every part of the Fearless macOS app and records the
# results with the source commit. Usage: macOS/scripts/verify.sh [--ui-tests]
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(cd "$here/.." && pwd)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="${FEARLESS_MAC_REPORTS:-$here/build/reports/$stamp}"
mkdir -p "$out"
commit="$(git -C "$repo" rev-parse HEAD)"
dirty="$(git -C "$repo" status --porcelain -- macOS Native config | wc -l | tr -d ' ')"
echo "commit $commit (uncommitted paths: $dirty)" | tee "$out/source.txt"

run() {
  local name="$1"; shift
  echo "== $name"
  if "$@" >"$out/$name.log" 2>&1; then
    echo "   ok"
  else
    echo "   FAILED (see $out/$name.log)"; tail -40 "$out/$name.log"; exit 1
  fi
}

run walletcore-test swift test --package-path "$here/Packages/WalletCore" --scratch-path "$here/.build-verify/core"
run ui-test swift test --package-path "$here/Packages/FearlessMacUI" --scratch-path "$here/.build-verify/ui"
run engine-test swift test --package-path "$here/Packages/FearlessMacEngine" --scratch-path "$here/.build-verify/engine"
run xcodegen xcodegen --spec "$here/project.yml" --project "$here"
run app-build xcodebuild -project "$here/FearlessMac.xcodeproj" -scheme FearlessMac -configuration Debug \
  -derivedDataPath "$here/DerivedData" -destination 'platform=macOS' build
if [[ "${1:-}" == "--ui-tests" ]]; then
  run app-ui-test xcodebuild -project "$here/FearlessMac.xcodeproj" -scheme FearlessMac -configuration Debug \
    -derivedDataPath "$here/DerivedData" -destination 'platform=macOS' test
fi

app="$here/DerivedData/Build/Products/Debug/Fearless.app"
shasum -a 256 "$app/Contents/MacOS/Fearless" | tee "$out/app-binary.sha256"
grep -hE 'Test run with|Executed [0-9]+ tests|passed|failed' "$out"/*-test.log | tail -20 > "$out/summary.txt" || true
echo "reports: $out"
