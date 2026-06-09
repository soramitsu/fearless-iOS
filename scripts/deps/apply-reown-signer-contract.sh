#!/usr/bin/env bash
set -euo pipefail

# Reown 1.8.0's WalletConnectSigner target imports YttriumWrapper/Yttrium but
# does not declare those direct dependencies. Clean Xcode test builds can link
# WalletConnectSigner as an individual package framework and fail on Yttrium
# symbols unless the target contract is explicit.

BASE_DIR="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$BASE_DIR/SourcePackages}"
ALLOW_DERIVEDDATA_FALLBACK="${ALLOW_DERIVEDDATA_FALLBACK:-0}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"

patched=0
seen=0

wallet_connect_signer_has_yttrium_dependency() {
  local pkg="$1"

  /usr/bin/perl -0ne '
    exit(
      /\.target\(\s*
        name:\s*"WalletConnectSigner",\s*
        dependencies:\s*\[[^\]]*"YttriumWrapper"/sx ? 0 : 1
    )
  ' "$pkg"
}

candidate_roots=(
  "$SOURCE_PACKAGES_DIR/checkouts/reown-swift"
)

if [[ "$ALLOW_DERIVEDDATA_FALLBACK" == "1" ]]; then
  for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
    [[ -d "$dd/SourcePackages/checkouts/reown-swift" ]] || continue
    candidate_roots+=("$dd/SourcePackages/checkouts/reown-swift")
  done
fi

for root in "${candidate_roots[@]}"; do
  pkg="$root/Package.swift"
  [[ -f "$pkg" ]] || continue
  seen=$((seen + 1))
  chmod u+w "$pkg" 2>/dev/null || true

  if ! /usr/bin/grep -q 'name: "WalletConnectSigner",' "$pkg"; then
    continue
  fi

  if ! wallet_connect_signer_has_yttrium_dependency "$pkg"; then
    /usr/bin/perl -0pi -e '
      s{
        \.target\(\s*
            name:\s*"WalletConnectSigner",\s*
            dependencies:\s*\["WalletConnectNetworking"\]\s*
        \)
      }{.target(
            name: "WalletConnectSigner",
            dependencies: [
                "WalletConnectNetworking",
                "YttriumWrapper",
                .product(name: "Yttrium", package: "yttrium")
            ]
        )}sx
    ' "$pkg"
    patched=1
  fi
done

if [[ "$seen" -eq 0 ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    echo "[apply-reown-signer-contract] reown-swift checkout not found" >&2
    exit 1
  fi
  echo "[apply-reown-signer-contract] reown-swift checkout not found; skipping"
elif [[ "$patched" == "1" ]]; then
  echo "[apply-reown-signer-contract] Patched Reown WalletConnectSigner dependency contract"
else
  echo "[apply-reown-signer-contract] Reown WalletConnectSigner dependency contract already applied"
fi
