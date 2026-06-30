#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
OUT_DIR="${2:-$ROOT/build/native-crypto-upstream-delta}"

MODULEMAP_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.module.modulemap"
UMBRELLA_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto-umbrella.h"
LINKER_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag"

fail() {
  echo "[export-native-crypto-upstream-delta] $1" >&2
  exit 1
}

for required in "$MODULEMAP_TEMPLATE" "$UMBRELLA_TEMPLATE" "$LINKER_TEMPLATE"; do
  [[ -f "$required" ]] || fail "Missing required template: $required"
done

rm -rf "$OUT_DIR"
mkdir -p \
  "$OUT_DIR/Sources/IrohaCrypto/include" \
  "$OUT_DIR/Sources/IrohaCrypto"

cp "$MODULEMAP_TEMPLATE" "$OUT_DIR/Sources/IrohaCrypto/include/module.modulemap"
cp "$UMBRELLA_TEMPLATE" "$OUT_DIR/Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h"
cp "$UMBRELLA_TEMPLATE" "$OUT_DIR/Sources/IrohaCrypto/IrohaCrypto-umbrella.h"
cp "$LINKER_TEMPLATE" "$OUT_DIR/IrohaCrypto.linker-settings.swiftfrag"

cat > "$OUT_DIR/README.md" <<EOF
# Native Crypto Upstream Delta

This directory is the repo-owned export of the native crypto package-state contract that still needs to exist in the pinned \`shared-features-spm\` source.

Included artifacts:
- \`Sources/IrohaCrypto/include/module.modulemap\`
- \`Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h\`
- \`Sources/IrohaCrypto/IrohaCrypto-umbrella.h\`
- \`IrohaCrypto.linker-settings.swiftfrag\`

The linker-settings fragment belongs in the \`IrohaCrypto\` target of \`Package.swift\`.
EOF

echo "[export-native-crypto-upstream-delta] Exported native crypto upstream delta to $OUT_DIR"
