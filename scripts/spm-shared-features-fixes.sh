#!/usr/bin/env bash
set -euo pipefail

# Patches known issues in shared-features-spm after SPM resolution.
# - Adds missing RobinHood dependency to SSFModels target when absent.
#
# Usage:
#   scripts/spm-shared-features-fixes.sh [BASE_DIR]
# Default BASE_DIR: current working directory

BASE_DIR="${1:-$(pwd)}"

patch_manifest() {
  local pkg_swift="$1/SourcePackages/checkouts/shared-features-spm/Package.swift"
  if [[ -f "$pkg_swift" ]]; then
    if /usr/bin/grep -q 'name:\s*"SSFModels"' "$pkg_swift"; then
      # Ensure RobinHood present
      if ! /usr/bin/grep -q 'target(\s*name:\s*"SSFModels"[\s\S]*dependencies:\s*\[[^]]*RobinHood' "$pkg_swift"; then
        echo "[spm-fixes] Adding RobinHood to SSFModels dependencies in $pkg_swift"
        /usr/bin/sed -i '' -e 's/dependencies:\s*\[\s*"IrohaCrypto"\s*\]/dependencies: [ "IrohaCrypto", "RobinHood" ]/' "$pkg_swift" || true
      fi
      # Ensure BigInt present
      if ! /usr/bin/grep -q 'target(\s*name:\s*"SSFModels"[\s\S]*dependencies:\s*\[[^]]*BigInt' "$pkg_swift"; then
        echo "[spm-fixes] Adding BigInt to SSFModels dependencies in $pkg_swift"
        /usr/bin/sed -i '' -e 's/dependencies:\s*\[\s*"IrohaCrypto"\(,\s*"RobinHood"\)\?\s*\]/dependencies: [ "IrohaCrypto", "RobinHood", "BigInt" ]/' "$pkg_swift" || true
      fi
    fi
  else
    echo "[spm-fixes] Package.swift not found at $pkg_swift (skip)"
  fi
}

# Try workspace-level SourcePackages first
patch_manifest "$BASE_DIR"

# Also try DerivedData paths, in case SPM ignores clonedSourcePackagesDirPath
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/*; do
  [[ -d "$dd/SourcePackages/checkouts/shared-features-spm" ]] || continue
  patch_manifest "$dd"
done

echo "[spm-fixes] Completed shared-features-spm fixes"

# 2) Patch Web3 EthereumPrivateKey initializers to accept Data as [UInt8]
patch_private_key_calls() {
  local base="$1/SourcePackages/checkouts/shared-features-spm"
  [[ -d "$base" ]] || return 0
  echo "[spm-fixes] Patching EthereumPrivateKey initializers under $base"
  # Known occurrences in sources
  local f1="$base/Sources/SSFTransferService/WalletConnectTransferServiceAssembly.swift"
  local f2="$base/Sources/SSFTransferService/InternalServices/Ethereum/EthereumTransferServiceAssembly.swift"
  if [[ -f "$f1" ]]; then
    /usr/bin/sed -i '' -e 's/EthereumPrivateKey(privateKey: privateKey\.bytes)/EthereumPrivateKey(privateKey: Array(privateKey))/' "$f1" || true
  fi
  if [[ -f "$f2" ]]; then
    /usr/bin/sed -i '' -e 's/EthereumPrivateKey(privateKey: secretKeyData\.bytes)/EthereumPrivateKey(privateKey: Array(secretKeyData))/' "$f2" || true
  fi
}

# Apply in workspace and DerivedData
patch_private_key_calls "$BASE_DIR"
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/*; do
  patch_private_key_calls "$dd"
done

echo "[spm-fixes] Completed EthereumPrivateKey call patches"
