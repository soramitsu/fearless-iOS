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
  if [[ ! -f "$pkg_swift" ]]; then
    echo "[spm-fixes] Package.swift not found at $pkg_swift (skip)"
    return 0
  fi

  # Rewrite the SSFModels target dependencies line to include RobinHood and BigInt, using awk for BSD portability
  local tmp_file
  tmp_file=$(mktemp)
  awk '
    BEGIN{in_models=0; patched=0}
    /name:[[:space:]]*"SSFModels"/ {in_models=1}
    in_models==1 && /dependencies:[[:space:]]*\[/ {
      # Replace the entire dependencies array for SSFModels
      print "            dependencies: [ \"IrohaCrypto\", \"RobinHood\", \"BigInt\" ]";
      patched=1; next
    }
    /\)\s*,\s*$/ { if(in_models==1){ in_models=0 } }
    { print }
    END{ if(patched==1) { } }
  ' "$pkg_swift" > "$tmp_file"

  if ! diff -q "$pkg_swift" "$tmp_file" >/dev/null 2>&1; then
    echo "[spm-fixes] Updated SSFModels dependencies in $pkg_swift"
    if mv "$tmp_file" "$pkg_swift" 2>/dev/null; then
      :
    else
      echo "[spm-fixes] Skipping write (no permission) for $pkg_swift in this environment" >&2
      rm -f "$tmp_file"
    fi
  else
    rm -f "$tmp_file"
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
