#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT/SourcePackages}"
LINKER_TEMPLATE="$ROOT/scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag"
CHECKOUT_HELPER="$ROOT/scripts/deps/native-crypto-checkout-roots.sh"
STRICT_REQUIRED_PATCHES="${STRICT_REQUIRED_PATCHES:-0}"
PATCHED=0
FOUND=0

fail() {
  echo "[apply-native-crypto-package-contract] $1" >&2
  exit 1
}

read_template() {
  [[ -f "$LINKER_TEMPLATE" ]] || fail "Missing linker settings template at $LINKER_TEMPLATE"
  cat "$LINKER_TEMPLATE"
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

[[ -f "$CHECKOUT_HELPER" ]] || fail "Missing checkout helper at $CHECKOUT_HELPER"
# shellcheck source=/dev/null
source "$CHECKOUT_HELPER"

LINKER_BLOCK="$(read_template)"

patch_package_swift() {
  local package_swift="$1"

  if ! iroha_target_has_required_linker_settings "$LINKER_BLOCK" "$package_swift"; then
    local package_before
    package_before="$(mktemp)"
    cp "$package_swift" "$package_before"

    /usr/bin/perl -0pi -e '
      s{
        (\.target\(\s*name:\s*"IrohaCrypto".*?cSettings:\s*\[\s*\.headerSearchPath\("\."\)\s*\])
        (?:,\s*linkerSettings:\s*\[\s*.*?\s*\])?
      }{$1,\n'"$LINKER_BLOCK"'}sx
        or die "Unable to locate IrohaCrypto target cSettings block\n";
    ' "$package_swift"

    if ! cmp -s "$package_before" "$package_swift"; then
      PATCHED=1
    fi

    rm -f "$package_before"

    if ! iroha_target_has_required_linker_settings "$LINKER_BLOCK" "$package_swift"; then
      fail "Unable to normalize IrohaCrypto linker settings in $package_swift"
    fi
  fi

  iroha_target_has_required_linker_settings "$LINKER_BLOCK" "$package_swift" || fail "IrohaCrypto linker settings do not match the expected repo-owned block after patch: $package_swift"
  [[ "$(iroha_target_linker_block_count "$LINKER_BLOCK" "$package_swift")" == "1" ]] || fail "Expected exactly one IrohaCrypto linker-settings block after patch: $package_swift"
}

while IFS= read -r package_root; do
  package_swift="$package_root/Package.swift"
  [[ -f "$package_swift" ]] || continue
  FOUND=1
  patch_package_swift "$package_swift"
done < <(native_crypto_checkout_candidates "$ROOT" "$SOURCE_PACKAGES_DIR")

if [[ "$FOUND" != "1" ]]; then
  if [[ "$STRICT_REQUIRED_PATCHES" == "1" ]]; then
    fail "No materialized shared-features-spm Package.swift found under SourcePackages or repo-local DerivedData"
  fi

  echo "[apply-native-crypto-package-contract] shared-features-spm Package.swift not found in any materialized checkout (skip)"
  exit 0
fi

if [[ "$PATCHED" == "1" ]]; then
  echo "[apply-native-crypto-package-contract] Added explicit IrohaCrypto linker settings"
else
  echo "[apply-native-crypto-package-contract] IrohaCrypto linker settings already present"
fi
