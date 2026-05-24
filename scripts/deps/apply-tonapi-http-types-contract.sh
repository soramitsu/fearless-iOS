#!/usr/bin/env bash
set -euo pipefail

# ton-api-swift generated clients import HTTPTypes directly, but some package
# revisions omit that direct target dependency. Xcode clean test builds can then
# link TonAPI before HTTPTypes is linked into the product.

BASE_DIR="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$BASE_DIR/SourcePackages}"
ALLOW_DERIVEDDATA_FALLBACK="${ALLOW_DERIVEDDATA_FALLBACK:-0}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"

patched=0
seen=0

candidate_roots=(
  "$SOURCE_PACKAGES_DIR/checkouts/ton-api-swift"
)

if [[ "$ALLOW_DERIVEDDATA_FALLBACK" == "1" ]]; then
  for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
    [[ -d "$dd/SourcePackages/checkouts/ton-api-swift" ]] || continue
    candidate_roots+=("$dd/SourcePackages/checkouts/ton-api-swift")
  done
fi

for root in "${candidate_roots[@]}"; do
  pkg="$root/Package.swift"
  [[ -f "$pkg" ]] || continue
  seen=$((seen + 1))
  chmod u+w "$pkg" 2>/dev/null || true

  if ! /usr/bin/grep -q 'swift-http-types' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s/(\.package\(url:\s*"https:\/\/github\.com\/apple\/swift-openapi-runtime",\s*\.upToNextMinor\(from:\s*"0\.3\.0"\)\),)/$1\n        .package(url: "https:\/\/github.com\/apple\/swift-http-types", .upToNextMajor(from: "1.0.0")),/s
    ' "$pkg"
    patched=1
  fi

  /usr/bin/sed -i '' \
    -e 's/\.package(url: "https:\/\/github.com\/apple\/swift-http-types", \.upToNextMinor(from: "1.0.0"))/.package(url: "https:\/\/github.com\/apple\/swift-http-types", .upToNextMajor(from: "1.0.0"))/' \
    "$pkg" || true

  if ! /usr/bin/grep -q 'name: "HTTPTypes"' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s{
        (\.product\(\s*
            name:\s*"OpenAPIRuntime",\s*
            package:\s*"swift-openapi-runtime"\s*
        \))
      }{$1,
                    .product(
                        name: "HTTPTypes",
                        package: "swift-http-types"
                    )}gsx
    ' "$pkg"
    patched=1
  fi
done

if [[ "$seen" -eq 0 ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    echo "[apply-tonapi-http-types-contract] ton-api-swift checkout not found" >&2
    exit 1
  fi
  echo "[apply-tonapi-http-types-contract] ton-api-swift checkout not found; skipping"
elif [[ "$patched" == "1" ]]; then
  echo "[apply-tonapi-http-types-contract] Patched TonAPI HTTPTypes dependency contract"
else
  echo "[apply-tonapi-http-types-contract] TonAPI HTTPTypes dependency contract already applied"
fi
