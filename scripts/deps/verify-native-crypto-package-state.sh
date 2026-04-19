#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT/SourcePackages}"
LINKER_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag"
MODULEMAP_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.module.modulemap"
UMBRELLA_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto-umbrella.h"
CHECKOUT_HELPER="$ROOT/scripts/deps/native-crypto-checkout-roots.sh"
FOUND=0

fail() {
  echo "[verify-native-crypto-package-state] $1" >&2
  exit 1
}

missing_checkout() {
  echo "[verify-native-crypto-package-state] Resolved native crypto checkout missing: $1" >&2
  exit 2
}

iroha_target_linker_block_count() {
  local unused="$1"
  local file="$2"
  /usr/bin/perl -0e '
    my ($unused, $file) = @ARGV;
    open my $fh, "<", $file or exit 1;
    local $/;
    my $content = <$fh>;
    if ($content =~ /\.target\(\s*name:\s*"IrohaCrypto".*?\n\s*\),/sg) {
      my $target = $&;
      my $count = () = ($target =~ /linkerSettings:\s*\[/sg);
      print $count;
      exit 0;
    }
    exit 1;
  ' "$unused" "$file"
}

iroha_target_has_required_linker_settings() {
  local unused="$1"
  local file="$2"
  /usr/bin/perl -0e '
    my ($unused, $file) = @ARGV;
    open my $fh, "<", $file or exit 1;
    local $/;
    my $content = <$fh>;
    if ($content =~ /\.target\(\s*name:\s*"IrohaCrypto".*?\n\s*\),/sg) {
      my $target = $&;
      exit 1 if $target !~ /linkerSettings:\s*\[/s;
      for my $framework ("sorawallet") {
        exit 1 if index($target, ".linkedFramework(\"$framework\")") < 0;
      }
      for my $framework ("blake2lib", "libed25519", "sr25519lib") {
        exit 1 if index($target, ".linkedFramework(\"$framework\")") >= 0;
      }
      exit 0;
    }
    exit 1;
  ' "$unused" "$file"
}

[[ -f "$LINKER_TEMPLATE" ]] || missing_checkout "$LINKER_TEMPLATE"
[[ -f "$MODULEMAP_TEMPLATE" ]] || missing_checkout "$MODULEMAP_TEMPLATE"
[[ -f "$UMBRELLA_TEMPLATE" ]] || missing_checkout "$UMBRELLA_TEMPLATE"
[[ -f "$CHECKOUT_HELPER" ]] || missing_checkout "$CHECKOUT_HELPER"

LINKER_BLOCK="$(cat "$LINKER_TEMPLATE")"
# shellcheck source=/dev/null
source "$CHECKOUT_HELPER"

verify_package_root() {
  local package_root="$1"
  local package_swift="$package_root/Package.swift"
  local modulemap="$package_root/Sources/IrohaCrypto/include/module.modulemap"
  local umbrella_include="$package_root/Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h"
  local umbrella_parent="$package_root/Sources/IrohaCrypto/IrohaCrypto-umbrella.h"

  [[ -d "$package_root" ]] || missing_checkout "$package_root"
  [[ -f "$package_swift" ]] || missing_checkout "$package_swift"
  [[ -f "$modulemap" ]] || missing_checkout "$modulemap"
  [[ -f "$umbrella_include" ]] || missing_checkout "$umbrella_include"
  [[ -f "$umbrella_parent" ]] || missing_checkout "$umbrella_parent"

  iroha_target_has_required_linker_settings "$LINKER_BLOCK" "$package_swift" || fail "IrohaCrypto linker settings do not match the expected repo-owned contract: $package_swift"
  [[ "$(iroha_target_linker_block_count "$LINKER_BLOCK" "$package_swift")" == "1" ]] || fail "Expected exactly one IrohaCrypto linker-settings block matching the repo-owned contract: $package_swift"
  cmp -s "$MODULEMAP_TEMPLATE" "$modulemap" || fail "IrohaCrypto module.modulemap does not match the expected repo-owned template: $modulemap"
  cmp -s "$UMBRELLA_TEMPLATE" "$umbrella_include" || fail "Include umbrella header does not match the expected template: $umbrella_include"
  cmp -s "$UMBRELLA_TEMPLATE" "$umbrella_parent" || fail "Parent umbrella header does not match the expected template: $umbrella_parent"
}

while IFS= read -r package_root; do
  FOUND=1
  verify_package_root "$package_root"
  echo "[verify-native-crypto-package-state] Package root: $package_root"
done < <(native_crypto_checkout_candidates "$ROOT" "$SOURCE_PACKAGES_DIR")

[[ "$FOUND" == "1" ]] || missing_checkout "shared-features-spm under SourcePackages or repo-local DerivedData"

echo "[verify-native-crypto-package-state] OK"
