#!/usr/bin/env bash
set -euo pipefail

# Patches known issues in shared-features-spm after SPM resolution.
# - Adds missing explicit dependencies to shared-features targets when absent.
#
# Usage:
#   scripts/spm-shared-features-fixes.sh [BASE_DIR]
# Default BASE_DIR: current working directory

BASE_DIR="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$BASE_DIR/SourcePackages}"
SOURCE_PACKAGES_BASE="$(dirname "$SOURCE_PACKAGES_DIR")"
ALLOW_DERIVEDDATA_FALLBACK="${ALLOW_DERIVEDDATA_FALLBACK:-0}"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"
SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS="${SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS:-0}"
REQUIRED_PATCH_COUNT=0
CHECKOUT_HELPER="$BASE_DIR/scripts/deps/native-crypto-checkout-roots.sh"

each_checkout_base() {
  local package_root
  local saw_any=0
  # Always include the caller-provided SourcePackages base first.
  printf '%s\n' "$SOURCE_PACKAGES_BASE"

  if [[ -f "$CHECKOUT_HELPER" ]]; then
    # shellcheck source=/dev/null
    source "$CHECKOUT_HELPER"
    while IFS= read -r package_root; do
      saw_any=1
      printf '%s\n' "$(dirname "$(dirname "$(dirname "$package_root")")")"
    done < <(native_crypto_checkout_candidates "$BASE_DIR" "$SOURCE_PACKAGES_DIR")
  fi

  if [[ "$saw_any" == "0" && "$ALLOW_DERIVEDDATA_FALLBACK" == "1" ]]; then
    for dd in "$HOME/Library/Developer/Xcode/DerivedData"/* "$BASE_DIR/DerivedData"/*; do
      [[ -d "$dd/SourcePackages/checkouts/shared-features-spm" ]] || continue
      printf '%s\n' "$dd"
    done
  fi
}

patch_manifest() {
  local pkg_swift="$1/SourcePackages/checkouts/shared-features-spm/Package.swift"
  if [[ ! -f "$pkg_swift" ]]; then
    echo "[spm-fixes] Package.swift not found at $pkg_swift (skip)"
    return 0
  fi

  REQUIRED_PATCH_COUNT=$((REQUIRED_PATCH_COUNT + 1))

  # Normalize Web3 dependency to the soramitsu fork to avoid duplicate package identities.
  /usr/bin/sed -E -i '' \
    -e 's|https://github.com/bnsports/Web3.swift.git|https://github.com/soramitsu/web3-swift|g' \
    -e 's/package:[[:space:]]*"Web3\.swift"/package: "web3-swift"/g' \
    "$pkg_swift" || true

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

  # Rewrite the SSFModels target dependencies block to include RobinHood, BigInt, and preserve Ton deps.
  local models_before
  models_before="$(mktemp)"
  cp "$pkg_swift" "$models_before"
  /usr/bin/perl -0pi -e '
    s{
      (\.target\(\s*name:\s*"SSFModels",\s*dependencies:\s*)\[[^\]]*\]
    }{$1\[
                "IrohaCrypto",
                "RobinHood",
                .product(name: "BigInt", package: "BigInt")
            \]}sx
      or die "Unable to locate SSFModels dependencies block\n";
  ' "$pkg_swift" || true

  if ! diff -q "$pkg_swift" "$models_before" >/dev/null 2>&1; then
    echo "[spm-fixes] Updated SSFModels dependencies in $pkg_swift"
  fi
  rm -f "$models_before"

  # Ensure SSFCrypto declares modules imported directly.
  local crypto_before
  crypto_before="$(mktemp)"
  cp "$pkg_swift" "$crypto_before"
  /usr/bin/perl -0pi -e '
    s{
      (\.target\(\s*name:\s*"SSFCrypto",\s*dependencies:\s*)\[[^\]]*\]
    }{$1\[
                "IrohaCrypto",
                "SSFUtils",
                "SSFModels",
                "keccak",
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "secp256k1", package: "secp256k1.swift")
            \]}sx
      or die "Unable to locate SSFCrypto dependencies block\n";
  ' "$pkg_swift" || true

  if ! diff -q "$pkg_swift" "$crypto_before" >/dev/null 2>&1; then
    echo "[spm-fixes] Updated SSFCrypto dependencies (direct imports)"
  fi
  rm -f "$crypto_before"

  # Ensure SSFPolkaswap has explicit SPM deps it imports directly.
  local polkaswap_before
  polkaswap_before="$(mktemp)"
  cp "$pkg_swift" "$polkaswap_before"
  /usr/bin/perl -0pi -e '
    s{
      (\.target\(\s*name:\s*"SSFPolkaswap",\s*dependencies:\s*)\[[^\]]*\]
    }{$1\[
                "SSFUtils",
                "SSFChainRegistry",
                "RobinHood",
                "SSFModels",
                "SSFStorageQueryKit",
                "SSFPools",
                "sorawallet",
                "SSFPoolsStorage",
                "SSFExtrinsicKit",
                "SSFSigner",
                "SSFEraKit",
                "SoraKeystore",
                "SwiftyBeaver",
                .product(name: "Reachability", package: "Reachability.swift")
            \]}sx
      or die "Unable to locate SSFPolkaswap dependencies block\n";
  ' "$pkg_swift" || true

  if ! diff -q "$pkg_swift" "$polkaswap_before" >/dev/null 2>&1; then
    echo "[spm-fixes] Updated SSFPolkaswap dependencies (explicit signer/era/extrinsic + network deps)"
  fi
  rm -f "$polkaswap_before"

  # Ensure SSFSingleValueCache treats its Core Data model as a package resource.
  local single_value_before
  single_value_before="$(mktemp)"
  cp "$pkg_swift" "$single_value_before"
  /usr/bin/perl -0pi -e '
    s{
      \.target\(\s*
        name:\s*"SSFSingleValueCache",\s*
        dependencies:\s*\["RobinHood"\]\s*
      \)
    }{.target(
            name: "SSFSingleValueCache",
            dependencies: ["RobinHood"],
            resources: [.process("CacheDataModel.xcdatamodeld")]
        )}sx
  ' "$pkg_swift" || true

  if ! diff -q "$pkg_swift" "$single_value_before" >/dev/null 2>&1; then
    echo "[spm-fixes] Added SSFSingleValueCache Core Data model resource"
  fi
  rm -f "$single_value_before"

}

while IFS= read -r checkout_base; do
  patch_manifest "$checkout_base"
done < <(each_checkout_base)

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
      -e 's/secretKeyData\.bytes/Array(secretKeyData)/g' \
      -e 's/privateKey\.bytes/Array(privateKey)/g' \
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

while IFS= read -r checkout_base; do
  patch_private_key_calls "$checkout_base"
done < <(each_checkout_base)

echo "[spm-fixes] Completed EthereumPrivateKey call patches (with verification)"

# 3) Normalize SSFCrypto AddressFactory compatibility without inventing new types
patch_address_factory_struct() {
  local base_checkout="$1/SourcePackages/checkouts/shared-features-spm"
  local file="$base_checkout/Sources/SSFCrypto/Classes/AddressConversion.swift"
  # Ensure sources are writable (avoid permission denied when editing)
  if [[ -d "$base_checkout/Sources" ]]; then
    chmod -R u+w "$base_checkout/Sources" 2>/dev/null || true
  fi
  if [[ -f "$file" ]]; then
    echo "[spm-fixes] Removing invalid AddressFactory compatibility shims in $file"
    /usr/bin/perl -0pi -e '
      s/\npublic extension AddressFactory \{\n    func address\(for accountId: AccountId, chainFormat: SFChainFormat\) throws -> AccountAddress \{\n        try Self\.address\(for: accountId, chainFormat: chainFormat\)\n    \}\n\n    func accountId\(from address: AccountAddress, chainFormat: SFChainFormat\) throws -> AccountId \{\n        try Self\.accountId\(from: address, chainFormat: chainFormat\)\n    \}\n\n    func accountId\(from address: AccountAddress, chain: ChainModel\) throws -> AccountId \{\n        try Self\.accountId\(from: address, chain: chain\)\n    \}\n\n    func randomAccountId\(for chainFormat: SFChainFormat\) -> AccountId \{\n        Self\.randomAccountId\(for: chainFormat\)\n    \}\n\}\n//s;
      s/\npublic typealias SFChainFormat = ChainFormat\n/\n/s;
    ' "$file" || true
  else
    echo "[spm-fixes] AddressConversion.swift not found at $file; performing broad search"
  fi

  # Leave enum-based AddressFactory definitions intact. Downstream rewrites handle call sites explicitly.
}

while IFS= read -r checkout_base; do
  patch_address_factory_struct "$checkout_base"
done < <(each_checkout_base)

echo "[spm-fixes] Normalized SSFCrypto AddressFactory compatibility shims"

# 4) Patch scrypt SIMD selection/headers to avoid simulator arch issues
patch_scrypt_sse2_guard() {
  local base="$1/SourcePackages/checkouts/shared-features-spm/Sources/scrypt"
  local file="$base/crypto_scrypt.c"
  local header="$base/include/scrypt.h"
  [[ -f "$file" ]] || return 0
  # Replace simulator-preferring SSE2 with an x86 SSSE3 guard, so arm64 sim never
  # references the SSE2 symbol when the implementation is compiled out.
  /usr/bin/perl -0pi -e '
    s/#if TARGET_IPHONE_SIMULATOR/#if defined(__SSSE3__) \&\& (defined(__i386__) || defined(__x86_64__))/g;
    s/#if defined\(__SSSE3__\)(?:\s*\&\&\s*\(defined\(__i386__\)\s*\|\|\s*defined\(__x86_64__\)\))*/#if defined(__SSSE3__) \&\& (defined(__i386__) || defined(__x86_64__))/g;
  ' "$file" || true

  # Newer shared-features revisions include arm_neon unconditionally in the public
  # scrypt header, which breaks x86_64 simulator dependency scanning.
  if [[ -f "$header" ]]; then
    /usr/bin/perl -0pi -e 's/#include <arm_neon\.h>/#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__) || defined(_M_ARM64)\n#include <arm_neon.h>\n#endif/' "$header" || true
  fi
}

while IFS= read -r checkout_base; do
  patch_scrypt_sse2_guard "$checkout_base"
done < <(each_checkout_base)

echo "[spm-fixes] Applied scrypt simulator arch guard patch"

# 5) Remove redundant sidecar static archives from wrapped native crypto frameworks.
# Xcode's embed step bitcode-strips every file in these framework bundles. The extra
# *.a payloads are not needed for app embedding and currently trip builtin-copy.
prune_native_crypto_framework_sidecars() {
  local binaries_root="$1/SourcePackages/checkouts/shared-features-spm/Binaries"
  local framework_dir

  [[ -d "$binaries_root" ]] || return 0

  for framework_dir in \
    "$binaries_root/blake2lib.xcframework/ios-arm64/blake2lib.framework" \
    "$binaries_root/libed25519.xcframework/ios-arm64/libed25519.framework" \
    "$binaries_root/sr25519lib.xcframework/ios-arm64/sr25519lib.framework"; do
    [[ -d "$framework_dir" ]] || continue
    chmod -R u+w "$framework_dir" 2>/dev/null || true

    for extra_archive in \
      "$framework_dir/blake2lib-arm64.a" \
      "$framework_dir/libed25519.a" \
      "$framework_dir/libed25519_sha2.a" \
      "$framework_dir/libsr25519crust.a"; do
      if [[ -f "$extra_archive" ]]; then
        echo "[spm-fixes] Removing redundant native crypto archive: $extra_archive"
        rm -f "$extra_archive"
      fi
    done
  done
}

while IFS= read -r checkout_base; do
  prune_native_crypto_framework_sidecars "$checkout_base"
done < <(each_checkout_base)

echo "[spm-fixes] Pruned native crypto framework sidecar archives"

# 6) SSFPolkaswap: make addressFactory a type reference when used as a dependency token
patch_polkaswap_addressfactory_usage() {
  local base_checkout="$1/SourcePackages/checkouts/shared-features-spm/Sources/SSFPolkaswap"
  [[ -d "$base_checkout" ]] || return 0
  echo "[spm-fixes] Normalizing SSFPolkaswap addressFactory usage under $base_checkout"
  chmod -R u+w "$base_checkout" 2>/dev/null || true
  # 5a) Generic metatype flattening: collapse any AddressFactory.Type.Type to AddressFactory.Type
  /usr/bin/find "$base_checkout" -type f -name "*.swift" -print0 2>/dev/null | \
    xargs -0 /usr/bin/sed -E -i '' \
      -e 's/([A-Za-z_][A-Za-z0-9_]*\.)?AddressFactory\s*\.\s*Type\s*\.\s*Type/\1AddressFactory.Type/g' || true

  /usr/bin/find "$base_checkout" -type f -name "*.swift" -print0 2>/dev/null | \
    xargs -0 /usr/bin/sed -E -i '' \
      -e 's/([^A-Za-z0-9_])(let|var)([[:space:]]+addressFactory[[:space:]]*:[[:space:]]*)([[:alnum:]_]+\.)?AddressFactory([^A-Za-z0-9_]|$)/\1\2\3\4AddressFactory.Type\5/g' \
      -e 's/([,(][[:space:]]*)addressFactory[[:space:]]*:[[:space:]]*([[:alnum:]_]+\.)?AddressFactory([^A-Za-z0-9_]|$)/\1addressFactory: \2AddressFactory.Type\3/g' \
      -e 's/addressFactory:[[:space:]]*AddressFactory[[:space:]]*=([[:space:]]*)AddressFactory\.self/addressFactory: AddressFactory.Type = AddressFactory.self/g' || true

  # Targeted fix for known files (ensure replacement even if patterns differ)
  local f1="$base_checkout/PolkaswapOperationFactory.swift"
  local f2="$base_checkout/RemotePolkaswapPoolsService.swift"
  for f in "$f1" "$f2"; do
    if [[ -f "$f" ]]; then
      chmod u+w "$f" 2>/dev/null || true
      # Targeted flattening in file (in case the generic pass missed due to formatting)
      /usr/bin/sed -E -i '' \
        -e 's/AddressFactory\s*\.\s*Type\s*\.\s*Type/AddressFactory.Type/g' \
        "$f" || true
      /usr/bin/sed -E -i '' \
        -e 's/(^|[^A-Za-z0-9_])private\s+let\s+addressFactory\s*:\s*([[:alnum:]_]+\.)?AddressFactory([^A-Za-z0-9_]|$)/\1private let addressFactory: \2AddressFactory.Type\3/g' \
        -e 's/\binit\(([^)]*)addressFactory\s*:\s*([[:alnum:]_]+\.)?AddressFactory([^A-Za-z0-9_]|$)/init(\1addressFactory: \2AddressFactory.Type\3/g' \
        "$f" || true
      # Fallback broad replacements for stray annotations
      /usr/bin/sed -E -i '' \
        -e 's/private\s+let\s+addressFactory\s*:\s*([[:alnum:]_]+\.)?AddressFactory\.Type\.Type/private let addressFactory: \1AddressFactory.Type/g' \
        -e 's/addressFactory\s*:\s*AddressFactory([^A-Za-z0-9_]|$)/addressFactory: AddressFactory.Type\1/g' \
        -e 's/addressFactory\s*:\s*SSFCrypto\.AddressFactory([^A-Za-z0-9_]|$)/addressFactory: SSFCrypto.AddressFactory.Type\1/g' \
        "$f" || true
      # 5b) Force assignment: prefer parameter when it is a metatype, otherwise fallback to concrete type literal
      if /usr/bin/grep -qE 'init\([^\)]*addressFactory\s*:\s*([[:alnum:]_]+\.)?AddressFactory\s*\.\s*Type' "$f"; then
        /usr/bin/sed -E -i '' \
          -e 's/^([[:space:]]*self[[:space:]]*\.[[:space:]]*addressFactory[[:space:]]*=[[:space:]]*)(AddressFactory\s*\.\s*self|type\(of:\s*addressFactory\s*\)|addressFactory)([[:space:]]*(\/\/.*)?$)/\1addressFactory\3/g' \
          "$f" || true
      else
        /usr/bin/sed -E -i '' \
          -e 's/^([[:space:]]*self[[:space:]]*\.[[:space:]]*addressFactory[[:space:]]*=[[:space:]]*)(AddressFactory\s*\.\s*self|addressFactory)([[:space:]]*(\/\/.*)?$)/\1type(of: addressFactory)\3/g' \
          "$f" || true
      fi
    fi
  done
}

while IFS= read -r checkout_base; do
  patch_polkaswap_addressfactory_usage "$checkout_base"
done < <(each_checkout_base)

echo "[spm-fixes] Patched SSFPolkaswap addressFactory usage (type tokens)"

cleanup_stale_embedded_native_crypto_frameworks() {
  local frameworks_root

  for frameworks_root in \
    "$BASE_DIR/build/DerivedData/Build/Products"/*/fearless.app/Frameworks \
    "$BASE_DIR/DerivedData/Build/Products"/*/fearless.app/Frameworks; do
    [[ -d "$frameworks_root" ]] || continue

    for framework_name in blake2lib.framework libed25519.framework sr25519lib.framework; do
      if [[ -d "$frameworks_root/$framework_name" ]]; then
        echo "[spm-fixes] Removing stale embedded framework: $frameworks_root/$framework_name"
        rm -rf "${frameworks_root:?}/$framework_name"
      fi
    done
  done
}

cleanup_stale_embedded_native_crypto_frameworks

echo "[spm-fixes] Cleaned stale embedded native crypto frameworks"

# 7) SSFSingleValueCache: make the Core Data model a package resource and keep
# the generated class module-qualified. Simulator builds currently do not emit
# the generated class for this Swift package target, while device archives do.
patch_single_value_cache_coredata_class() {
  local base_checkout="$1/SourcePackages/checkouts/shared-features-spm/Sources/SSFSingleValueCache"
  local entity_file="$base_checkout/CDSingleValue.swift"
  local model_file="$base_checkout/CacheDataModel.xcdatamodeld/CacheDataModel.xcdatamodel/contents"

  [[ -d "$base_checkout" ]] || return 0
  chmod -R u+w "$base_checkout" 2>/dev/null || true

  if [[ "$SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS" == "1" ]]; then
    if [[ ! -f "$entity_file" ]]; then
      cat > "$entity_file" <<'SWIFT'
import CoreData
import Foundation

@objc(CDSingleValue)
public final class CDSingleValue: NSManagedObject {
    @NSManaged public var identifier: String?
    @NSManaged public var payload: Data?
}
SWIFT
      echo "[spm-fixes] Added simulator SSFSingleValueCache/CDSingleValue manual Core Data class"
    fi
  elif [[ -f "$entity_file" ]] && /usr/bin/grep -q "public final class CDSingleValue: NSManagedObject" "$entity_file"; then
    rm -f "$entity_file"
    echo "[spm-fixes] Removed redundant SSFSingleValueCache/CDSingleValue manual Core Data class"
  fi

  if [[ -f "$model_file" ]]; then
    local codegen_type="class"
    if [[ "$SSF_SINGLE_VALUE_CACHE_MANUAL_CLASS" == "1" ]]; then
      codegen_type="none"
    fi

    /usr/bin/sed -i '' \
      -e 's/representedClassName="CDSingleValue"/representedClassName="SSFSingleValueCache.CDSingleValue"/' \
      -e "s|codeGenerationType=\"class\"|codeGenerationType=\"$codegen_type\"|" \
      -e "s|codeGenerationType=\"manual/none\"|codeGenerationType=\"$codegen_type\"|" \
      -e "s|codeGenerationType=\"none\"|codeGenerationType=\"$codegen_type\"|" \
      "$model_file" || true
  fi
}

while IFS= read -r checkout_base; do
  patch_single_value_cache_coredata_class "$checkout_base"
done < <(each_checkout_base)

echo "[spm-fixes] Patched SSFSingleValueCache Core Data model"

# 8) Expose public initializers for SSFPools value types used by app presenters.
# Newer shared-features-spm revisions keep memberwise inits internal, which breaks
# app-side construction and previously led to recursive compatibility shims.
patch_ssfpools_public_initializers() {
  local base_checkout="$1/SourcePackages/checkouts/shared-features-spm/Sources/SSFPools"
  local pooled="$base_checkout/PooledAssetInfo.swift"
  local supply="$base_checkout/SupplyLiquidityInfo.swift"
  local remove="$base_checkout/RemoveLiquidityInfo.swift"

  [[ -d "$base_checkout" ]] || return 0
  chmod -R u+w "$base_checkout" 2>/dev/null || true

  if [[ -f "$pooled" ]] && ! /usr/bin/grep -q "public init(id: String, precision: Int16)" "$pooled"; then
    /usr/bin/perl -0pi -e '
      s/public struct PooledAssetInfo \{\n    public let id: String\n    public let precision: Int16\n\}/public struct PooledAssetInfo {\n    public let id: String\n    public let precision: Int16\n\n    public init(id: String, precision: Int16) {\n        self.id = id\n        self.precision = precision\n    }\n}/s
    ' "$pooled" || true
    echo "[spm-fixes] Added public init to SSFPools/PooledAssetInfo"
  fi

  if [[ -f "$supply" ]] && ! /usr/bin/grep -q "public init(" "$supply"; then
    /usr/bin/perl -0pi -e '
      s/public let slippage: Decimal\n\n    public var amountMinA/public let slippage: Decimal\n\n    public init(\n        dexId: String,\n        baseAsset: PooledAssetInfo,\n        targetAsset: PooledAssetInfo,\n        baseAssetAmount: Decimal,\n        targetAssetAmount: Decimal,\n        slippage: Decimal\n    ) {\n        self.dexId = dexId\n        self.baseAsset = baseAsset\n        self.targetAsset = targetAsset\n        self.baseAssetAmount = baseAssetAmount\n        self.targetAssetAmount = targetAssetAmount\n        self.slippage = slippage\n    }\n\n    public var amountMinA/s
    ' "$supply" || true
    echo "[spm-fixes] Added public init to SSFPools/SupplyLiquidityInfo"
  fi

  if [[ -f "$remove" ]] && ! /usr/bin/grep -q "public init(" "$remove"; then
    /usr/bin/perl -0pi -e '
      s/public let slippage: Decimal\n\n    public var amountMinA/public let slippage: Decimal\n\n    public init(\n        dexId: String,\n        baseAsset: PooledAssetInfo,\n        targetAsset: PooledAssetInfo,\n        baseAssetAmount: Decimal,\n        targetAssetAmount: Decimal,\n        baseAssetReserves: Decimal,\n        totalIssuances: Decimal,\n        slippage: Decimal\n    ) {\n        self.dexId = dexId\n        self.baseAsset = baseAsset\n        self.targetAsset = targetAsset\n        self.baseAssetAmount = baseAssetAmount\n        self.targetAssetAmount = targetAssetAmount\n        self.baseAssetReserves = baseAssetReserves\n        self.totalIssuances = totalIssuances\n        self.slippage = slippage\n    }\n\n    public var amountMinA/s
    ' "$remove" || true
    echo "[spm-fixes] Added public init to SSFPools/RemoveLiquidityInfo"
  fi
}

while IFS= read -r checkout_base; do
  patch_ssfpools_public_initializers "$checkout_base"
done < <(each_checkout_base)

apply_native_crypto_contracts() {
  local package_contract="$BASE_DIR/scripts/deps/apply-native-crypto-package-contract.sh"
  local modulemap_contract="$BASE_DIR/scripts/deps/apply-native-crypto-modulemap-contract.sh"
  local strict="${STRICT_REQUIRED_PATCHES:-0}"

  if [[ -f "$package_contract" ]]; then
    if ! SOURCE_PACKAGES_DIR="$SOURCE_PACKAGES_DIR" \
      STRICT_REQUIRED_PATCHES="$STRICT_REQUIRED_PATCHES" \
      bash "$package_contract" "$BASE_DIR"; then
      if [[ "$strict" == "1" ]]; then
        echo "[spm-fixes] Native crypto package contract failed in strict mode" >&2
        exit 1
      fi
      echo "[spm-fixes] Native crypto package contract failed (non-strict, continuing)" >&2
    fi
  fi

  if [[ -f "$modulemap_contract" ]]; then
    if ! SOURCE_PACKAGES_DIR="$SOURCE_PACKAGES_DIR" \
      STRICT_REQUIRED_PATCHES="$STRICT_REQUIRED_PATCHES" \
      bash "$modulemap_contract" "$BASE_DIR"; then
      if [[ "$strict" == "1" ]]; then
        echo "[spm-fixes] Native crypto modulemap contract failed in strict mode" >&2
        exit 1
      fi
      echo "[spm-fixes] Native crypto modulemap contract failed (non-strict, continuing)" >&2
    fi
  fi
}

apply_native_crypto_contracts

echo "[spm-fixes] Re-applied native crypto package/modulemap contracts"

if [[ "$STRICT_REQUIRED_PATCHES" == "1" && "$REQUIRED_PATCH_COUNT" -eq 0 ]]; then
  echo "[spm-fixes] No shared-features-spm checkout was available to patch" >&2
  exit 1
fi

echo "[spm-fixes] Required checkout patch count: $REQUIRED_PATCH_COUNT"
