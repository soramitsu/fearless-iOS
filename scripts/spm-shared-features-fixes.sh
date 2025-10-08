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

  # 0) Ensure top-level BigInt package dependency exists
  if ! /usr/bin/grep -q "BigInt.git" "$pkg_swift"; then
    echo "[spm-fixes] Injecting BigInt package dependency"
    # Insert BigInt package line into the top-level dependencies array
    # This is a best-effort injection; keeps formatting minimal
    /usr/bin/awk '
      BEGIN{in_deps=0; injected=0}
      /dependencies:[[:space:]]*\[/ { print; in_deps=1; next }
      in_deps==1 {
        if(injected==0){
          print "        .package(url: \"https://github.com/attaswift/BigInt.git\", from: \"5.3.0\"),";
          injected=1;
        }
        print;
        if($0 ~ /\]/){ in_deps=0 }
        next
      }
      { print }
    ' "$pkg_swift" > "$pkg_swift.tmp" && mv "$pkg_swift.tmp" "$pkg_swift" || true
  fi

  # Rewrite the SSFModels target dependencies line to include RobinHood and BigInt.
  # Try sed first for common single-line forms; fall back to awk block rewrite.
  local tmp_file
  tmp_file=$(mktemp)
  # sed path: only replace the simple single-line list when present
  if /usr/bin/grep -qE 'name:[[:space:]]*"SSFModels"' "$pkg_swift" && \
     /usr/bin/grep -qE 'target\([[:space:]]*name:[[:space:]]*"SSFModels"[\s\S]*dependencies:[[:space:]]*\[[[:space:]]*"IrohaCrypto"[[:space:]]*\]' "$pkg_swift"; then
    /usr/bin/sed -E 's/(target\([[:space:]]*name:[[:space:]]*"SSFModels"[\s\S]*dependencies:[[:space:]]*)\[[^\]]*\]/\1[ "IrohaCrypto", "RobinHood", "BigInt" ]/' "$pkg_swift" > "$tmp_file" || cp "$pkg_swift" "$tmp_file"
  else
    awk '
      BEGIN{in_models=0; patched=0}
      /name:[[:space:]]*"SSFModels"/ {in_models=1}
      in_models==1 && /dependencies:[[:space:]]*\[/ {
        print "            dependencies: [ \"IrohaCrypto\", \"RobinHood\", \"BigInt\" ]";
        patched=1; next
      }
      /\)\s*,\s*$/ { if(in_models==1){ in_models=0 } }
      { print }
    ' "$pkg_swift" > "$tmp_file"
  fi

  if ! diff -q "$pkg_swift" "$tmp_file" >/dev/null 2>&1; then
    echo "[spm-fixes] Updated SSFModels dependencies in $pkg_swift"
    /usr/bin/grep -nE 'target\([[:space:]]*name:[[:space:]]*"SSFModels"|dependencies:[[:space:]]*\[' "$tmp_file" | sed -n '1,6p' || true
    if mv "$tmp_file" "$pkg_swift" 2>/dev/null; then
      :
    else
      echo "[spm-fixes] Skipping write (no permission) for $pkg_swift in this environment" >&2
      rm -f "$tmp_file"
    fi
  else
    rm -f "$tmp_file"
  fi

  # Ensure SSFPolkaswap has explicit SPM deps it imports directly (Reachability, SwiftyBeaver, SoraKeystore)
  local pkg_tmp
  pkg_tmp=$(mktemp)
  awk '
    BEGIN{in_target=0; changed=0}
    /target\(\s*name:\s*"SSFPolkaswap"/ { in_target=1 }
    in_target==1 && /dependencies:\s*\[/ {
      # Normalize dependencies for SSFPolkaswap
      print "            dependencies: [\n                \"SSFUtils\",\n                \"SSFChainRegistry\",\n                \"RobinHood\",\n                \"SSFModels\",\n                \"SSFStorageQueryKit\",\n                \"SSFPools\",\n                \"sorawallet\",\n                \"SSFPoolsStorage\",\n                \"SSFExtrinsicKit\",\n                \"SoraKeystore\",\n                \"SwiftyBeaver\",\n                .product(name: \"Reachability\", package: \"Reachability.swift\")\n            ]";
      changed=1; next
    }
    /\)\s*,\s*$/ { if(in_target==1){ in_target=0 } }
    { print }
  ' "$pkg_swift" > "$pkg_tmp"
  if ! diff -q "$pkg_swift" "$pkg_tmp" >/dev/null 2>&1; then
    echo "[spm-fixes] Updated SSFPolkaswap dependencies (added Reachability, SwiftyBeaver, SoraKeystore)"
    if mv "$pkg_tmp" "$pkg_swift" 2>/dev/null; then :; else rm -f "$pkg_tmp"; fi
  else
    rm -f "$pkg_tmp"
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
