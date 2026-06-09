#!/usr/bin/env bash
set -euo pipefail

# web3-swift imports SwiftNIO/WebSocketKit through its Foundation HTTP client,
# but the 7.7.7 package manifest does not declare every directly used SwiftNIO
# product. Clean Xcode test builds can link Web3 before those products are
# available unless the target contract is explicit.

BASE_DIR="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$BASE_DIR/SourcePackages}"
ALLOW_DERIVEDDATA_FALLBACK="${ALLOW_DERIVEDDATA_FALLBACK:-0}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"

patched=0
seen=0

candidate_roots=(
  "$SOURCE_PACKAGES_DIR/checkouts/web3-swift"
)

if [[ "$ALLOW_DERIVEDDATA_FALLBACK" == "1" ]]; then
  for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
    [[ -d "$dd/SourcePackages/checkouts/web3-swift" ]] || continue
    candidate_roots+=("$dd/SourcePackages/checkouts/web3-swift")
  done
fi

for root in "${candidate_roots[@]}"; do
  pkg="$root/Package.swift"
  [[ -f "$pkg" ]] || continue
  seen=$((seen + 1))
  chmod u+w "$pkg" 2>/dev/null || true

  if ! /usr/bin/grep -q 'github.com/apple/swift-nio.git' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s/(\.package\(url:\s*"https:\/\/github\.com\/vapor\/websocket-kit",\s*\.upToNextMajor\(from:\s*"2\.6\.1"\)\),)/$1\n        .package(url: "https:\/\/github.com\/apple\/swift-nio.git", from: "2.0.0"),/s
    ' "$pkg"
    patched=1
  fi

  if ! /usr/bin/grep -q 'swift-nio-ssl' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s/(\.package\(url:\s*"https:\/\/github\.com\/vapor\/websocket-kit",\s*\.upToNextMajor\(from:\s*"2\.6\.1"\)\),)/$1\n        .package(url: "https:\/\/github.com\/apple\/swift-nio-ssl.git", from: "2.0.0"),/s
    ' "$pkg"
    patched=1
  fi

  if ! /usr/bin/grep -q 'name: "NIOCore"' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s{
        (\.product\(name:\s*"WebSocketKit",\s*package:\s*"websocket-kit"\),)
      }{$1\n                .product(name: "NIOCore", package: "swift-nio"),}gsx
    ' "$pkg"
    patched=1
  fi

  if ! /usr/bin/grep -q 'name: "NIOHTTP1"' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s{
        (\.product\(name:\s*"WebSocketKit",\s*package:\s*"websocket-kit"\),)
      }{$1\n                .product(name: "NIOHTTP1", package: "swift-nio"),}gsx
    ' "$pkg"
    patched=1
  fi

  if ! /usr/bin/grep -q 'name: "NIOPosix"' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s{
        (\.product\(name:\s*"WebSocketKit",\s*package:\s*"websocket-kit"\),)
      }{$1\n                .product(name: "NIOPosix", package: "swift-nio"),}gsx
    ' "$pkg"
    patched=1
  fi

  if ! /usr/bin/grep -q 'name: "NIOSSL"' "$pkg"; then
    /usr/bin/perl -0pi -e '
      s{
        (\.product\(name:\s*"WebSocketKit",\s*package:\s*"websocket-kit"\),)
      }{$1\n                .product(name: "NIOSSL", package: "swift-nio-ssl"),}gsx
    ' "$pkg"
    patched=1
  fi
done

if [[ "$seen" -eq 0 ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    echo "[apply-web3-nio-ssl-contract] web3-swift checkout not found" >&2
    exit 1
  fi
  echo "[apply-web3-nio-ssl-contract] web3-swift checkout not found; skipping"
elif [[ "$patched" == "1" ]]; then
  echo "[apply-web3-nio-ssl-contract] Patched Web3 NIOSSL dependency contract"
else
  echo "[apply-web3-nio-ssl-contract] Web3 NIOSSL dependency contract already applied"
fi
