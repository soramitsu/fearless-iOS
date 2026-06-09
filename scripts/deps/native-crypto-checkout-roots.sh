#!/usr/bin/env bash

native_crypto_checkout_candidates() {
  local root="$1"
  local source_packages_dir="${2:-$root/SourcePackages}"
  local allow_deriveddata_fallback="${ALLOW_DERIVEDDATA_FALLBACK:-0}"
  local explicit_root
  local seen="|"
  local candidate

  explicit_root="$(dirname "$source_packages_dir")/SourcePackages/checkouts/shared-features-spm"

  emit_unique_existing() {
    local path="$1"

    [[ -d "$path" ]] || return 0

    if [[ "$seen" != *"|$path|"* ]]; then
      printf '%s\n' "$path"
      seen="${seen}${path}|"
      return 0
    fi

    return 0
  }

  emit_unique_existing "$explicit_root"

  for candidate in \
    "$root/build/DerivedData/SourcePackages/checkouts/shared-features-spm" \
    "$root/DerivedData/SourcePackages/checkouts/shared-features-spm" \
    "$root/build/DerivedData"/*/SourcePackages/checkouts/shared-features-spm \
    "$root/DerivedData"/*/SourcePackages/checkouts/shared-features-spm; do
    [[ -d "$candidate" ]] || continue
    emit_unique_existing "$candidate"
  done

  [[ "$allow_deriveddata_fallback" == "1" ]] || return 0

  for candidate in "$HOME/Library/Developer/Xcode/DerivedData"/*/SourcePackages/checkouts/shared-features-spm; do
    [[ -d "$candidate" ]] || continue
    emit_unique_existing "$candidate"
  done
}
