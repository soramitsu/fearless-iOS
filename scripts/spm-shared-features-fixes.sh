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
    /usr/bin/sed -E $'s/(target\([[:space:]]*name:[[:space:]]*"SSFModels"[\s\S]*dependencies:[[:space:]]*)\[[^\]]*\]/\1[ \"IrohaCrypto\", \"RobinHood\", .product(name: \"BigInt\", package: \"BigInt\") ]/' "$pkg_swift" > "$tmp_file" || cp "$pkg_swift" "$tmp_file"
  else
    awk '
      BEGIN{in_models=0; patched=0}
      /name:[[:space:]]*"SSFModels"/ {in_models=1}
      in_models==1 && /dependencies:[[:space:]]*\[/ {
        print "            dependencies: [ \"IrohaCrypto\", \"RobinHood\", .product(name: \"BigInt\", package: \"BigInt\") ]";
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
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
  [[ -d "$dd/SourcePackages/checkouts/shared-features-spm" ]] || continue
  patch_manifest "$dd"
done

echo "[spm-fixes] Completed shared-features-spm fixes"

# 2) Patch Web3 EthereumPrivateKey initializers to accept Data as [UInt8]
patch_private_key_calls() {
  local root="$1"
  local patched=0
  # Look for both known files under any shared-features-spm checkout below the root
  while IFS= read -r -d '' file; do
    echo "[spm-fixes] Patching Data.bytes -> Array(data) in: $file"
    # Apply several tolerant patterns
    /usr/bin/sed -E -i '' \
      -e 's/EthereumPrivateKey\(\s*privateKey:\s*privateKey\s*\.\s*bytes\s*\)/EthereumPrivateKey(privateKey: Array(privateKey))/' \
      -e 's/EthereumPrivateKey\(\s*privateKey:\s*secretKeyData\s*\.\s*bytes\s*\)/EthereumPrivateKey(privateKey: Array(secretKeyData))/' \
      -e 's/([[:<:]]privateKey[[:>:]]\s*)\.\s*bytes/Array(\1)/g' \
      -e 's/([[:<:]]secretKeyData[[:>:]]\s*)\.\s*bytes/Array(\1)/g' \
      "$file" || true

    # Report remaining occurrences if any
    if /usr/bin/grep -n "\.bytes" "$file" >/dev/null 2>&1; then
      echo "[spm-fixes] After patch, '.bytes' still present in $file:" >&2
      /usr/bin/grep -n "\.bytes" "$file" | sed -n '1,4p' >&2 || true
    else
      patched=$((patched+1))
    fi
  done < <(/usr/bin/find "$root" -type f \( \
      -path "*/checkouts/shared-features-spm/Sources/SSFTransferService/WalletConnectTransferServiceAssembly.swift" -o \
      -path "*/checkouts/shared-features-spm/Sources/SSFTransferService/InternalServices/Ethereum/EthereumTransferServiceAssembly.swift" \
    \) -print0 2>/dev/null)

  echo "[spm-fixes] Patched $patched file(s) under $root"
}

# Apply in workspace and common DerivedData roots
patch_private_key_calls "$BASE_DIR"
for dd in "$HOME/Library/Developer/Xcode/DerivedData" "$BASE_DIR/DerivedData"; do
  [[ -d "$dd" ]] || continue
  for sub in "$dd"/*; do
    [[ -d "$sub" ]] || continue
    patch_private_key_calls "$sub"
  done
done

echo "[spm-fixes] Completed EthereumPrivateKey call patches (with verification)"

# 3) Convert SSFCrypto AddressFactory from enum to struct (allow instantiation)
patch_address_factory_struct() {
  local base_checkout="$1/SourcePackages/checkouts/shared-features-spm"
  local file="$base_checkout/Sources/SSFCrypto/Classes/AddressConversion.swift"
  if [[ -f "$file" ]]; then
    echo "[spm-fixes] Converting AddressFactory enum->struct in $file"
    # Replace public enum AddressFactory with public struct AddressFactory
    /usr/bin/sed -i '' -e 's/^public[[:space:]]\+enum[[:space:]]\+AddressFactory/public struct AddressFactory/' "$file" || true
    # Simple append of instance wrappers at end of file if missing
    if ! /usr/bin/grep -q "extension AddressFactory" "$file"; then
      cat >> "$file" <<'EOF'

public extension AddressFactory {
    func address(for accountId: AccountId, chainFormat: SFChainFormat) throws -> AccountAddress {
        try Self.address(for: accountId, chainFormat: chainFormat)
    }

    func accountId(from address: AccountAddress, chainFormat: SFChainFormat) throws -> AccountId {
        try Self.accountId(from: address, chainFormat: chainFormat)
    }

    func accountId(from address: AccountAddress, chain: ChainModel) throws -> AccountId {
        try Self.accountId(from: address, chain: chain)
    }

    func randomAccountId(for chainFormat: SFChainFormat) -> AccountId {
        Self.randomAccountId(for: chainFormat)
    }
}
EOF
    fi
  else
    echo "[spm-fixes] AddressConversion.swift not found at $file; performing broad search"
  fi

  # Broad fallback: patch any file in shared-features-spm declaring enum AddressFactory
  local sources_dir="$base_checkout/Sources"
  if [[ -d "$sources_dir" ]]; then
    while IFS= read -r -d '' f; do
      echo "[spm-fixes] Converting AddressFactory in: $f"
      /usr/bin/sed -E -i '' \
        -e 's/^[[:space:]]*public[[:space:]]+enum[[:space:]]+AddressFactory/public struct AddressFactory/' \
        -e 's/^[[:space:]]*enum[[:space:]]+AddressFactory/struct AddressFactory/' \
        "$f" || true
    done < <(/usr/bin/grep -RIl "^[[:space:]]*(public[[:space:]]+)?enum[[:space:]]+AddressFactory" "$sources_dir" 2>/dev/null | tr '\n' '\0')
  fi
}

patch_address_factory_struct "$BASE_DIR"
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
  patch_address_factory_struct "$dd"
done

echo "[spm-fixes] Converted SSFCrypto AddressFactory to struct (instance-friendly)"

# 4) Patch scrypt SSE2 selection to avoid undefined symbol on arm64 simulators
patch_scrypt_sse2_guard() {
  local base="$1/SourcePackages/checkouts/shared-features-spm/Sources/scrypt"
  local file="$base/crypto_scrypt.c"
  [[ -f "$file" ]] || return 0
  # Replace simulator-preferring SSE2 with SSSE3 feature guard, so on arm64 sim we don't reference the SSE2 symbol.
  /usr/bin/sed -i '' \
    -e $'s/#if TARGET_IPHONE_SIMULATOR/#if defined(__SSSE3__)/' \
    "$file" || true
}

# Apply in workspace and DerivedData
patch_scrypt_sse2_guard "$BASE_DIR"
for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
  patch_scrypt_sse2_guard "$dd"
done

echo "[spm-fixes] Applied scrypt SSE2 guard patch (arm64-sim safe)"
