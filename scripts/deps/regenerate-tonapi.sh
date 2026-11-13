#!/bin/bash
# Regenerates Packages/TonAPI/Sources/TonAPI from Packages/TonAPI/openapi/openapi.yml with
# Apple's swift-openapi-generator 0.3.1 (Apache-2.0), built at the exact dependency revisions in
# scripts/deps/tonapi-generator/Package.resolved, and fails if the result differs from the
# committed sources.
#
# Usage: scripts/deps/regenerate-tonapi.sh            # verify the committed sources
#        scripts/deps/regenerate-tonapi.sh --write    # replace them with fresh output
#
# It downloads the generator and its dependencies from GitHub, so run it where that is allowed.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$ROOT/scripts/deps/tonapi-generator/Package.swift" "$ROOT/scripts/deps/tonapi-generator/Package.resolved" "$WORK/"
(cd "$WORK" && swift build -c release --product swift-openapi-generator --only-use-versions-from-resolved-file)

mkdir -p "$WORK/out"
"$WORK/.build/release/swift-openapi-generator" generate \
  --mode types --mode client \
  --output-directory "$WORK/out" \
  "$ROOT/Packages/TonAPI/openapi/openapi.yml"
python3 -I "$ROOT/scripts/deps/tonapi-generator/postprocess.py" "$WORK/out/Types.swift"

TARGET="$ROOT/Packages/TonAPI/Sources/TonAPI"
if [[ "${1:-}" == "--write" ]]; then
  cp "$WORK/out/Client.swift" "$WORK/out/Types.swift" "$TARGET/"
fi

for file in Client.swift Types.swift; do
  if ! cmp -s "$WORK/out/$file" "$TARGET/$file"; then
    echo "error: $file differs from the generator output; run with --write and review the diff" >&2
    exit 1
  fi
done
echo "TonAPI sources match swift-openapi-generator 0.3.1 output for openapi/openapi.yml"
