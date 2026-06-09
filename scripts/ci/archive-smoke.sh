#!/usr/bin/env bash
set -euo pipefail

# Runs an unsigned archive build by default to validate the iOS archive path
# without requiring Apple signing material. Set REQUIRE_SIGNED_ARCHIVE=1 to
# require runtime keys and a verified signed IPA. By default this uses manual
# signing assets; set SIGNING_MODE=automatic to use Xcode account-managed
# archive signing plus cloud-managed distribution export.

ROOT="${1:-$(pwd)}"
WORKSPACE="${WORKSPACE:-fearless.xcworkspace}"
SCHEME="${SCHEME:-fearless}"
CONFIGURATION="${CONFIGURATION:-Dev}"
SP_DIR="${SP_DIR:-$ROOT/SourcePackages}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/fearless-smoke.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/build/fearless-smoke-export}"
REQUIRE_SIGNED_ARCHIVE="${REQUIRE_SIGNED_ARCHIVE:-0}"
SKIP_BOOTSTRAP="${SKIP_BOOTSTRAP:-0}"
SIGNED_ARCHIVE="${SIGNED_ARCHIVE:-$REQUIRE_SIGNED_ARCHIVE}"
EXPORT_SIGNED_ARCHIVE="${EXPORT_SIGNED_ARCHIVE:-$SIGNED_ARCHIVE}"
EXPORT_METHOD="${EXPORT_METHOD:-release-testing}"
PRECHECK_ONLY="${PRECHECK_ONLY:-0}"
INSTALL_EXPORTED_IPA="${INSTALL_EXPORTED_IPA:-0}"
INSTALL_DEVICE_ID="${INSTALL_DEVICE_ID:-${DEVICE_ID:-}}"
INSTALL_LAUNCH_APP="${INSTALL_LAUNCH_APP:-${LAUNCH_APP:-1}}"
INSTALL_TIMEOUT_SECONDS="${INSTALL_TIMEOUT_SECONDS:-120}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"
SIGNING_MODE="${SIGNING_MODE:-manual}"
if [[ -z "${REQUIRE_RUNTIME_KEYS:-}" ]]; then
  if [[ "$REQUIRE_SIGNED_ARCHIVE" == "1" || "$SIGNED_ARCHIVE" == "1" ]]; then
    REQUIRE_RUNTIME_KEYS=1
  else
    REQUIRE_RUNTIME_KEYS=0
  fi
fi
SIGNING_TEAM_ID="${SIGNING_TEAM_ID:-YLWWUD25VZ}"
if [[ -z "${SIGNING_IDENTITY_PATTERN:-}" ]]; then
  if [[ "$SIGNING_MODE" == "automatic" ]]; then
    SIGNING_IDENTITY_PATTERN="Apple Development"
  else
    SIGNING_IDENTITY_PATTERN="Apple Distribution"
  fi
fi
SIGNING_PROFILE_SPECIFIER="${SIGNING_PROFILE_SPECIFIER:-fearlesswallet-dev-adhoc}"
SIGNING_BUNDLE_ID="${SIGNING_BUNDLE_ID:-jp.co.soramitsu.fearlesswallet.dev}"
SIGNING_REQUIRED_APP_GROUP="${SIGNING_REQUIRED_APP_GROUP:-group.jp.co.soramitsu.fearlesswallet.walletconnect}"
AUTOMATIC_ARCHIVE_IDENTITY="${AUTOMATIC_ARCHIVE_IDENTITY:-Apple Development}"
AUTOMATIC_EXPORT_SIGNING_CERTIFICATE="${AUTOMATIC_EXPORT_SIGNING_CERTIFICATE:-}"
APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_API_KEY_PATH:-}}"
APP_STORE_CONNECT_API_KEY_CONTENT="${APP_STORE_CONNECT_API_KEY_CONTENT:-${ASC_API_KEY_CONTENT:-}}"
APP_STORE_CONNECT_API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_API_KEY_ID:-}}"
APP_STORE_CONNECT_API_KEY_ISSUER_ID="${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-${ASC_API_KEY_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-}}}"
RUNTIME_ENV_FILE="${ENV_FILE:-}"
APP_STORE_CONNECT_AUTH_ARGS=()
EXPORTED_IPA_PATH=""

cd "$ROOT"

TEMP_PATHS=()

register_temp_path() {
  local path="$1"

  TEMP_PATHS+=("$path")
}

cleanup_temp_paths() {
  local path

  if ((${#TEMP_PATHS[@]})); then
    for path in "${TEMP_PATHS[@]}"; do
      [[ -n "$path" ]] && rm -rf "$path"
    done
  fi
}

trap cleanup_temp_paths EXIT

resolve_runtime_env_file() {
  if [[ -z "$RUNTIME_ENV_FILE" ]]; then
    if [[ -f "$ROOT/.env.local" ]]; then
      RUNTIME_ENV_FILE="$ROOT/.env.local"
    elif [[ -f "$ROOT/.env" ]]; then
      RUNTIME_ENV_FILE="$ROOT/.env"
    fi
  fi
}

load_runtime_env_file() {
  resolve_runtime_env_file

  if [[ -n "$RUNTIME_ENV_FILE" && -f "$RUNTIME_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$RUNTIME_ENV_FILE"
    set +a
    echo "[archive-smoke] Loaded runtime key environment from $RUNTIME_ENV_FILE"
  fi
}

normalize_app_store_connect_auth_env() {
  APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_API_KEY_PATH:-}}"
  APP_STORE_CONNECT_API_KEY_CONTENT="${APP_STORE_CONNECT_API_KEY_CONTENT:-${ASC_API_KEY_CONTENT:-}}"
  APP_STORE_CONNECT_API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_API_KEY_ID:-}}"
  APP_STORE_CONNECT_API_KEY_ISSUER_ID="${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-${ASC_API_KEY_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-}}}"
}

has_app_store_connect_auth_inputs() {
  [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ||
     -n "${APP_STORE_CONNECT_API_KEY_CONTENT:-}" ||
     -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ||
     -n "${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-}" ]]
}

configure_app_store_connect_auth_args() {
  local missing=0

  normalize_app_store_connect_auth_env
  APP_STORE_CONNECT_AUTH_ARGS=()

  if ! has_app_store_connect_auth_inputs; then
    return 0
  fi

  if [[ -n "${APP_STORE_CONNECT_API_KEY_CONTENT:-}" && -z "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
    APP_STORE_CONNECT_API_KEY_PATH="$(mktemp)"
    register_temp_path "$APP_STORE_CONNECT_API_KEY_PATH"
    chmod 600 "$APP_STORE_CONNECT_API_KEY_PATH"
    printf '%s' "$APP_STORE_CONNECT_API_KEY_CONTENT" >"$APP_STORE_CONNECT_API_KEY_PATH"
    echo "[archive-smoke] Loaded App Store Connect API key from environment content."
  fi

  for key in \
    APP_STORE_CONNECT_API_KEY_PATH \
    APP_STORE_CONNECT_API_KEY_ID \
    APP_STORE_CONNECT_API_KEY_ISSUER_ID; do
    if [[ -z "${!key:-}" ]]; then
      echo "[archive-smoke] ERROR: ${key} is required when using App Store Connect API key signing." >&2
      missing=1
    fi
  done

  if [[ "$missing" == "1" ]]; then
    exit 2
  fi

  if [[ ! -f "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    echo "[archive-smoke] ERROR: APP_STORE_CONNECT_API_KEY_PATH does not exist: $APP_STORE_CONNECT_API_KEY_PATH" >&2
    exit 2
  fi

  APP_STORE_CONNECT_AUTH_ARGS=(
    -authenticationKeyPath "$APP_STORE_CONNECT_API_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_KEY_ISSUER_ID"
  )
  echo "[archive-smoke] App Store Connect API key authentication enabled."
}

provisioning_updates_enabled() {
  [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ||
     "$SIGNING_MODE" == "automatic" ||
     ${#APP_STORE_CONNECT_AUTH_ARGS[@]} -gt 0 ]]
}

case "$SIGNING_MODE" in
  manual | automatic)
    ;;
  *)
    echo "[archive-smoke] ERROR: SIGNING_MODE must be 'manual' or 'automatic', got '${SIGNING_MODE}'" >&2
    exit 2
    ;;
esac

if [[ "$EXPORT_SIGNED_ARCHIVE" == "1" && "$SIGNED_ARCHIVE" != "1" ]]; then
  echo "[archive-smoke] ERROR: EXPORT_SIGNED_ARCHIVE=1 requires SIGNED_ARCHIVE=1" >&2
  exit 2
fi

if [[ "$SIGNING_MODE" == "automatic" && "$SIGNED_ARCHIVE" == "1" && "$EXPORT_SIGNED_ARCHIVE" != "1" ]]; then
  echo "[archive-smoke] ERROR: SIGNING_MODE=automatic requires EXPORT_SIGNED_ARCHIVE=1 for release validation" >&2
  exit 2
fi

load_runtime_env_file
configure_app_store_connect_auth_args

find_signing_identity_count() {
  security find-identity -v -p codesigning 2>/dev/null |
    awk -v team="$SIGNING_TEAM_ID" -v pattern="$SIGNING_IDENTITY_PATTERN" -v mode="$SIGNING_MODE" '
      /^[[:space:]]*[0-9]+\)/ {
        if ((mode == "automatic" || team == "" || index($0, "(" team ")") > 0) &&
            (pattern == "" || index($0, pattern) > 0)) {
          count++
        }
      }
      END { print count + 0 }
    '
}

find_team_identity_lines() {
  security find-identity -v -p codesigning 2>/dev/null |
    awk -v team="$SIGNING_TEAM_ID" -v pattern="$SIGNING_IDENTITY_PATTERN" -v mode="$SIGNING_MODE" '
      /^[[:space:]]*[0-9]+\)/ {
        if ((mode == "automatic" && (pattern == "" || index($0, pattern) > 0)) ||
            (mode != "automatic" && (team == "" || index($0, "(" team ")") > 0))) {
          print
        }
      }
    '
}

profile_search_dirs() {
  for profiles_dir in \
    "$HOME/Library/MobileDevice/Provisioning Profiles" \
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/ProvisioningProfiles"; do
    printf '%s\n' "$profiles_dir"
  done
}

find_installed_profiles() {
  while IFS= read -r profiles_dir; do
    [[ -d "$profiles_dir" ]] || continue
    find "$profiles_dir" -maxdepth 1 -name '*.mobileprovision' -print 2>/dev/null || true
  done < <(profile_search_dirs)
}

profile_get_task_allow() {
  local plist_path="$1"

  /usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$plist_path" 2>/dev/null || true
}

profile_has_provisioned_devices() {
  local plist_path="$1"

  /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices:0' "$plist_path" >/dev/null 2>&1
}

export_method_requires_provisioned_devices() {
  case "$EXPORT_METHOD" in
    ad-hoc | release-testing | debugging)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

export_method_uses_development_profile() {
  [[ "$EXPORT_METHOD" == "debugging" ]]
}

find_matching_profile_count() {
  local expected_app_identifier="${SIGNING_TEAM_ID}.${SIGNING_BUNDLE_ID}"
  local now
  local count=0

  now="$(date -u +%s)"

  while IFS= read -r profile; do
    local decoded
    decoded="$(mktemp)"
    register_temp_path "$decoded"

    if security cms -D -i "$profile" >"$decoded" 2>/dev/null; then
      local name
      local team
      local app_identifier
      local expiration_date
      local expiration_seconds
      local get_task_allow
      local reject_reasons=()

      name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$decoded" 2>/dev/null || true)"
      team="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$decoded" 2>/dev/null || true)"
      app_identifier="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$decoded" 2>/dev/null || true)"

      if [[ "$team" == "$SIGNING_TEAM_ID" &&
            "$app_identifier" == "$expected_app_identifier" ]]; then
        if [[ "$SIGNING_MODE" == "manual" && "$name" != "$SIGNING_PROFILE_SPECIFIER" ]]; then
          rm -f "$decoded"
          continue
        fi

        expiration_date="$(plutil -extract ExpirationDate raw -o - "$decoded" 2>/dev/null || true)"
        expiration_seconds="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$expiration_date" +%s 2>/dev/null || echo 0)"

        if [[ "$expiration_seconds" == "0" || "$expiration_seconds" -le "$now" ]]; then
          reject_reasons+=("expired ${expiration_date:-unknown}")
        fi

        if ! /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' "$decoded" 2>/dev/null |
          grep -Fq "$SIGNING_REQUIRED_APP_GROUP"; then
          reject_reasons+=("missing App Group ${SIGNING_REQUIRED_APP_GROUP}")
        fi

        get_task_allow="$(profile_get_task_allow "$decoded")"
        if export_method_uses_development_profile; then
          if [[ "$get_task_allow" != "true" ]]; then
            reject_reasons+=("get-task-allow ${get_task_allow:-missing}, expected true for ${EXPORT_METHOD}")
          fi
        elif [[ "$get_task_allow" != "false" ]]; then
          reject_reasons+=("get-task-allow ${get_task_allow:-missing}, expected false for ${EXPORT_METHOD}")
        fi

        if export_method_requires_provisioned_devices && ! profile_has_provisioned_devices "$decoded"; then
          reject_reasons+=("missing ProvisionedDevices for ${EXPORT_METHOD} export")
        fi

        if ((${#reject_reasons[@]})); then
          echo "[archive-smoke] Profile '${name:-$profile}' rejected: ${reject_reasons[*]}" >&2
        else
          count=$((count + 1))
        fi
      fi
    fi

    rm -f "$decoded"
  done < <(find_installed_profiles)

  echo "$count"
}

report_signing_diagnostics() {
  local expected_app_identifier="${SIGNING_TEAM_ID}.${SIGNING_BUNDLE_ID}"
  local identity_lines
  local matching_profiles
  local matching_profile_count=0

  identity_lines="$(find_team_identity_lines)"
  matching_profiles="$(mktemp)"
  register_temp_path "$matching_profiles"

  if [[ -n "$identity_lines" ]]; then
    if [[ "$SIGNING_MODE" == "automatic" ]]; then
      echo "[archive-smoke]   installed automatic archive identities matching '${SIGNING_IDENTITY_PATTERN}':"
    else
      echo "[archive-smoke]   installed code signing identities for team '${SIGNING_TEAM_ID}':"
    fi
    printf '%s\n' "$identity_lines" | sed 's/^/[archive-smoke]     /'
  else
    if [[ "$SIGNING_MODE" == "automatic" ]]; then
      echo "[archive-smoke]   no installed automatic archive identities found matching '${SIGNING_IDENTITY_PATTERN}'"
    else
      echo "[archive-smoke]   no installed code signing identities found for team '${SIGNING_TEAM_ID}'"
    fi
  fi

  while IFS= read -r profile; do
    local decoded
    decoded="$(mktemp)"
    register_temp_path "$decoded"

    if security cms -D -i "$profile" >"$decoded" 2>/dev/null; then
      local name
      local team
      local app_identifier
      local expiration_date
      local app_groups
      local get_task_allow
      local has_provisioned_devices

      name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$decoded" 2>/dev/null || true)"
      team="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$decoded" 2>/dev/null || true)"
      app_identifier="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$decoded" 2>/dev/null || true)"

      if [[ "$name" == "$SIGNING_PROFILE_SPECIFIER" ||
            "$app_identifier" == "$expected_app_identifier" ||
            "$team" == "$SIGNING_TEAM_ID" && "$app_identifier" == *".${SIGNING_BUNDLE_ID}" ]]; then
        expiration_date="$(plutil -extract ExpirationDate raw -o - "$decoded" 2>/dev/null || true)"
        get_task_allow="$(profile_get_task_allow "$decoded")"
        if profile_has_provisioned_devices "$decoded"; then
          has_provisioned_devices="yes"
        else
          has_provisioned_devices="no"
        fi
        app_groups="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' "$decoded" 2>/dev/null |
          sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
          paste -sd ',' - 2>/dev/null || true)"

        matching_profile_count=$((matching_profile_count + 1))
        {
          printf 'path=%s\n' "$profile"
          printf 'name=%s\n' "${name:-unknown}"
          printf 'team=%s\n' "${team:-unknown}"
          printf 'app-id=%s\n' "${app_identifier:-unknown}"
          printf 'expires=%s\n' "${expiration_date:-unknown}"
          printf 'get-task-allow=%s\n' "${get_task_allow:-unknown}"
          printf 'has-provisioned-devices=%s\n' "$has_provisioned_devices"
          printf 'app-groups=%s\n' "${app_groups:-none}"
          printf '\n'
        } >>"$matching_profiles"
      fi
    fi

    rm -f "$decoded"
  done < <(find_installed_profiles)

  if ((matching_profile_count)); then
    echo "[archive-smoke]   candidate provisioning profiles found:"
    sed 's/^/[archive-smoke]     /' "$matching_profiles"
  else
    echo "[archive-smoke]   no provisioning profile candidates found for '${SIGNING_PROFILE_SPECIFIER}' or '${expected_app_identifier}'"
  fi

  rm -f "$matching_profiles"

  if [[ "$SIGNING_MODE" == "manual" ]]; then
    echo "[archive-smoke]   note: Xcode account login alone does not satisfy manual archive signing;"
    echo "[archive-smoke]         the certificate private key and matching provisioning profile must be installed locally or in CI."
  else
    echo "[archive-smoke]   note: automatic signing requires an Xcode account or API key with provisioning updates enabled;"
    echo "[archive-smoke]         release validation still verifies the exported IPA signature, team, bundle id, profile, and App Group."
  fi
}

report_signing_material() {
  local identity_count="$1"
  local profile_count="$2"

  if [[ "$identity_count" == "0" || "$profile_count" == "0" ]]; then
    echo "[archive-smoke] Signing material missing for ${CONFIGURATION} archive:"
    echo "[archive-smoke]   identity '${SIGNING_IDENTITY_PATTERN}' for team '${SIGNING_TEAM_ID}': ${identity_count}"
    if [[ "$SIGNING_MODE" == "manual" ]]; then
      echo "[archive-smoke]   profile '${SIGNING_PROFILE_SPECIFIER}' for '${SIGNING_TEAM_ID}.${SIGNING_BUNDLE_ID}': ${profile_count}"
    else
      echo "[archive-smoke]   ${EXPORT_METHOD} profile for '${SIGNING_TEAM_ID}.${SIGNING_BUNDLE_ID}': ${profile_count}"
    fi

    if [[ "$identity_count" == "0" ]]; then
      if [[ "$SIGNING_MODE" == "manual" ]]; then
        echo "[archive-smoke]   install a matching distribution certificate with its private key"
      else
        echo "[archive-smoke]   install or allow Xcode to create a matching development signing certificate"
      fi
    fi

    if [[ "$profile_count" == "0" ]]; then
      if [[ "$SIGNING_MODE" == "manual" ]]; then
        echo "[archive-smoke]   install an unexpired profile that includes App Group '${SIGNING_REQUIRED_APP_GROUP}'"
      else
        echo "[archive-smoke]   install or allow Xcode to create an unexpired ${EXPORT_METHOD} profile that includes App Group '${SIGNING_REQUIRED_APP_GROUP}'"
      fi
    fi

    report_signing_diagnostics

    return 1
  fi

  if [[ "$SIGNING_MODE" == "manual" ]]; then
    echo "[archive-smoke] Signing material present for team '${SIGNING_TEAM_ID}', profile '${SIGNING_PROFILE_SPECIFIER}'."
  else
    echo "[archive-smoke] Automatic signing material present for team '${SIGNING_TEAM_ID}'."
  fi
}

assert_plist_array_contains() {
  local plist_path="$1"
  local key_path="$2"
  local expected_value="$3"
  local description="$4"
  local subject="${5:-signed archive}"

  if ! /usr/libexec/PlistBuddy -c "Print :${key_path}" "$plist_path" 2>/dev/null |
    grep -Fq "$expected_value"; then
    echo "[archive-smoke] ERROR: ${subject} is missing ${description} '${expected_value}'" >&2
    return 1
  fi
}

assert_plist_value_equals() {
  local plist_path="$1"
  local key_path="$2"
  local expected_value="$3"
  local description="$4"
  local subject="${5:-signed archive}"
  local actual_value

  actual_value="$(/usr/libexec/PlistBuddy -c "Print :${key_path}" "$plist_path" 2>/dev/null || true)"

  if [[ "$actual_value" != "$expected_value" ]]; then
    echo "[archive-smoke] ERROR: ${subject} has ${description} '${actual_value:-missing}', expected '${expected_value}'" >&2
    return 1
  fi
}

assert_profile_not_expired() {
  local plist_path="$1"
  local subject="$2"
  local expiration_date
  local expiration_seconds
  local now

  expiration_date="$(plutil -extract ExpirationDate raw -o - "$plist_path" 2>/dev/null || true)"
  expiration_seconds="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$expiration_date" +%s 2>/dev/null || echo 0)"
  now="$(date -u +%s)"

  if [[ "$expiration_seconds" == "0" || "$expiration_seconds" -le "$now" ]]; then
    echo "[archive-smoke] ERROR: ${subject} embedded profile is expired (${expiration_date:-unknown})" >&2
    return 1
  fi
}

assert_profile_release_distribution() {
  local plist_path="$1"
  local subject="$2"
  local get_task_allow
  local expected_get_task_allow="false"

  if export_method_uses_development_profile; then
    expected_get_task_allow="true"
  fi

  get_task_allow="$(profile_get_task_allow "$plist_path")"

  if [[ "$get_task_allow" != "$expected_get_task_allow" ]]; then
    echo "[archive-smoke] ERROR: ${subject} embedded profile has get-task-allow '${get_task_allow:-missing}', expected '${expected_get_task_allow}' for ${EXPORT_METHOD} export" >&2
    return 1
  fi
}

assert_profile_supports_export_method() {
  local plist_path="$1"
  local subject="$2"

  if export_method_requires_provisioned_devices && ! profile_has_provisioned_devices "$plist_path"; then
    echo "[archive-smoke] ERROR: ${subject} embedded profile is missing ProvisionedDevices for ${EXPORT_METHOD} export" >&2
    return 1
  fi
}

verify_app_bundle() {
  local app_path="$1"
  local artifact_label="$2"
  local entitlements
  local expected_app_identifier
  local info_plist

  if [[ -z "$app_path" || ! -d "$app_path" ]]; then
    echo "[archive-smoke] ERROR: ${artifact_label} does not contain an app bundle" >&2
    return 1
  fi

  info_plist="$app_path/Info.plist"
  if [[ ! -f "$info_plist" ]]; then
    echo "[archive-smoke] ERROR: ${artifact_label} is missing Info.plist" >&2
    return 1
  fi

  assert_plist_value_equals "$info_plist" "CFBundleIdentifier" "$SIGNING_BUNDLE_ID" "bundle identifier" "$artifact_label" || return 1

  codesign --verify --strict --verbose=2 "$app_path"

  entitlements="$(mktemp)"
  register_temp_path "$entitlements"
  if ! codesign -d --entitlements :- "$app_path" >"$entitlements" 2>/dev/null; then
    rm -f "$entitlements"
    return 1
  fi

  expected_app_identifier="${SIGNING_TEAM_ID}.${SIGNING_BUNDLE_ID}"

  if ! assert_plist_value_equals "$entitlements" "application-identifier" "$expected_app_identifier" "application identifier" "$artifact_label"; then
    rm -f "$entitlements"
    return 1
  fi

  if ! assert_plist_value_equals "$entitlements" "com.apple.developer.team-identifier" "$SIGNING_TEAM_ID" "team identifier" "$artifact_label"; then
    rm -f "$entitlements"
    return 1
  fi

  if ! assert_plist_array_contains "$entitlements" "com.apple.security.application-groups" "$SIGNING_REQUIRED_APP_GROUP" "App Group" "$artifact_label"; then
    rm -f "$entitlements"
    return 1
  fi

  rm -f "$entitlements"
}

verify_embedded_profile() {
  local profile_path="$1"
  local artifact_label="$2"
  local expected_app_identifier="${SIGNING_TEAM_ID}.${SIGNING_BUNDLE_ID}"
  local decoded

  if [[ ! -f "$profile_path" ]]; then
    echo "[archive-smoke] ERROR: ${artifact_label} is missing embedded.mobileprovision" >&2
    return 1
  fi

  decoded="$(mktemp)"
  register_temp_path "$decoded"
  if ! security cms -D -i "$profile_path" >"$decoded" 2>/dev/null; then
    rm -f "$decoded"
    echo "[archive-smoke] ERROR: could not decode ${artifact_label} embedded.mobileprovision" >&2
    return 1
  fi

  if [[ "$SIGNING_MODE" == "manual" ]] &&
    ! assert_plist_value_equals "$decoded" "Name" "$SIGNING_PROFILE_SPECIFIER" "profile name" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  if ! assert_plist_value_equals "$decoded" "TeamIdentifier:0" "$SIGNING_TEAM_ID" "profile team identifier" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  if ! assert_plist_value_equals "$decoded" "Entitlements:application-identifier" "$expected_app_identifier" "profile application identifier" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  if ! assert_plist_array_contains "$decoded" "Entitlements:com.apple.security.application-groups" "$SIGNING_REQUIRED_APP_GROUP" "profile App Group" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  if ! assert_profile_not_expired "$decoded" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  if ! assert_profile_release_distribution "$decoded" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  if ! assert_profile_supports_export_method "$decoded" "$artifact_label"; then
    rm -f "$decoded"
    return 1
  fi

  rm -f "$decoded"
}

verify_signed_archive() {
  local app_path

  app_path="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' -type d -print -quit 2>/dev/null || true)"
  verify_app_bundle "$app_path" "signed archive app" || return 1
  verify_embedded_profile "$app_path/embedded.mobileprovision" "signed archive app"
}

create_export_options_plist() {
  local export_options="$1"

  plutil -create xml1 "$export_options"
  /usr/libexec/PlistBuddy -c "Add :method string ${EXPORT_METHOD}" "$export_options"
  /usr/libexec/PlistBuddy -c "Add :teamID string ${SIGNING_TEAM_ID}" "$export_options"
  /usr/libexec/PlistBuddy -c "Add :signingStyle string ${SIGNING_MODE}" "$export_options"
  if [[ "$SIGNING_MODE" == "manual" ]]; then
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$export_options"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:${SIGNING_BUNDLE_ID} string ${SIGNING_PROFILE_SPECIFIER}" "$export_options"
  else
    if [[ -n "$AUTOMATIC_EXPORT_SIGNING_CERTIFICATE" ]]; then
      /usr/libexec/PlistBuddy -c "Add :signingCertificate string ${AUTOMATIC_EXPORT_SIGNING_CERTIFICATE}" "$export_options"
    fi
  fi
  /usr/libexec/PlistBuddy -c "Add :stripSwiftSymbols bool true" "$export_options"
  /usr/libexec/PlistBuddy -c "Add :compileBitcode bool false" "$export_options"
  /usr/libexec/PlistBuddy -c "Add :destination string export" "$export_options"
  /usr/libexec/PlistBuddy -c "Add :manageAppVersionAndBuildNumber bool false" "$export_options"
}

find_single_exported_ipa_path() {
  local ipa_files=()
  local ipa

  while IFS= read -r ipa; do
    ipa_files+=("$ipa")
  done < <(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -type f -print 2>/dev/null)

  if ((${#ipa_files[@]} == 0)); then
    echo "[archive-smoke] ERROR: export did not create an IPA in $EXPORT_PATH" >&2
    return 1
  fi

  if ((${#ipa_files[@]} > 1)); then
    echo "[archive-smoke] ERROR: export created multiple IPA files in $EXPORT_PATH" >&2
    printf '[archive-smoke]   %s\n' "${ipa_files[@]}" >&2
    return 1
  fi

  printf '%s\n' "${ipa_files[0]}"
}

verify_exported_ipa() {
  local ipa_path
  local package_dir
  local packaged_app

  ipa_path="$(find_single_exported_ipa_path)" || return 1

  package_dir="$(mktemp -d)"
  register_temp_path "$package_dir"
  if ! unzip -q "$ipa_path" -d "$package_dir"; then
    rm -rf "$package_dir"
    echo "[archive-smoke] ERROR: exported IPA could not be unzipped: $ipa_path" >&2
    return 1
  fi

  packaged_app="$(find "$package_dir/Payload" -maxdepth 1 -name '*.app' -type d -print -quit 2>/dev/null || true)"
  if [[ -z "$packaged_app" ]]; then
    rm -rf "$package_dir"
    echo "[archive-smoke] ERROR: exported IPA does not contain Payload/*.app" >&2
    return 1
  fi

  if ! verify_app_bundle "$packaged_app" "exported IPA app"; then
    rm -rf "$package_dir"
    return 1
  fi

  if ! verify_embedded_profile "$packaged_app/embedded.mobileprovision" "exported IPA app"; then
    rm -rf "$package_dir"
    return 1
  fi

  rm -rf "$package_dir"
  EXPORTED_IPA_PATH="$ipa_path"
  echo "[archive-smoke] Exported IPA OK: $EXPORTED_IPA_PATH"
}

install_exported_ipa() {
  if [[ -z "$EXPORTED_IPA_PATH" ]]; then
    EXPORTED_IPA_PATH="$(find_single_exported_ipa_path)" || return 1
  fi

  echo "[archive-smoke] Installing exported IPA on physical device."
  ROOT="$ROOT" \
    IPA_PATH="$EXPORTED_IPA_PATH" \
    BUNDLE_ID="$SIGNING_BUNDLE_ID" \
    DEVICE_ID="$INSTALL_DEVICE_ID" \
    LAUNCH_APP="$INSTALL_LAUNCH_APP" \
    TIMEOUT_SECONDS="$INSTALL_TIMEOUT_SECONDS" \
    scripts/ci/install-ipa-to-device.sh
}

export_signed_archive() {
  local export_options
  local export_args=()

  export_options="$(mktemp)"
  register_temp_path "$export_options"
  create_export_options_plist "$export_options"

  rm -rf "$EXPORT_PATH"
  mkdir -p "$EXPORT_PATH"

  export_args=(
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$export_options"
  )
  if provisioning_updates_enabled; then
    export_args+=(-allowProvisioningUpdates)
  fi
  if ((${#APP_STORE_CONNECT_AUTH_ARGS[@]})); then
    export_args+=("${APP_STORE_CONNECT_AUTH_ARGS[@]}")
  fi

  if ! xcodebuild "${export_args[@]}"; then
    rm -f "$export_options"
    if [[ "$SIGNING_MODE" == "automatic" ]]; then
      echo "[archive-smoke] Automatic export failed. Ensure Xcode has valid Apple account credentials" >&2
      echo "[archive-smoke] or provide local distribution signing material via manual signing." >&2
    fi
    return 1
  fi

  rm -f "$export_options"
  verify_exported_ipa
  if [[ "$INSTALL_EXPORTED_IPA" == "1" ]]; then
    install_exported_ipa
  fi
}

identity_count="$(find_signing_identity_count)"
profile_count="$(find_matching_profile_count)"

if [[ "$REQUIRE_SIGNED_ARCHIVE" == "1" || "$SIGNED_ARCHIVE" == "1" ]]; then
  missing_release_gate=0

  if ! report_signing_material "$identity_count" "$profile_count"; then
    if provisioning_updates_enabled; then
      echo "[archive-smoke] Continuing signed archive because provisioning updates are enabled; Xcode may download or create updated signing material."
    else
      missing_release_gate=1
    fi
  fi

  if [[ "$REQUIRE_RUNTIME_KEYS" == "1" ]]; then
    if ! STRICT_RUNTIME_KEYS=1 scripts/secrets/validate-runtime-keys.sh "$ROOT"; then
      missing_release_gate=1
    fi
  fi

  if [[ "$missing_release_gate" == "1" ]]; then
    exit 2
  fi
fi

if [[ "$PRECHECK_ONLY" == "1" ]]; then
  echo "[archive-smoke] Precheck OK for ${CONFIGURATION} archive (${SIGNING_MODE} signing, ${EXPORT_METHOD} export)."
  exit 0
fi

if [[ "$SKIP_BOOTSTRAP" != "1" ]]; then
  SP_DIR="$SP_DIR" bash scripts/ci/bootstrap.sh
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"
rm -rf "$ARCHIVE_PATH"

archive_kind="unsigned"
if [[ "$SIGNED_ARCHIVE" == "1" ]]; then
  archive_kind="signed"
  echo "[archive-smoke] Running signed ${CONFIGURATION} archive (${SIGNING_MODE} signing)"
  signed_archive_args=(
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -clonedSourcePackagesDirPath "$SP_DIR" \
    -disableAutomaticPackageResolution
  )
  if provisioning_updates_enabled; then
    signed_archive_args+=(-allowProvisioningUpdates)
  fi
  if ((${#APP_STORE_CONNECT_AUTH_ARGS[@]})); then
    signed_archive_args+=("${APP_STORE_CONNECT_AUTH_ARGS[@]}")
  fi
  if [[ "$SIGNING_MODE" == "automatic" ]]; then
    signed_archive_args+=(
      DEVELOPMENT_TEAM="$SIGNING_TEAM_ID"
      CODE_SIGN_STYLE=Automatic
      CODE_SIGN_IDENTITY="$AUTOMATIC_ARCHIVE_IDENTITY"
      PROVISIONING_PROFILE_SPECIFIER=
      PRODUCT_BUNDLE_IDENTIFIER="$SIGNING_BUNDLE_ID"
    )
  fi
  xcodebuild "${signed_archive_args[@]}" clean archive
else
  echo "[archive-smoke] Running unsigned ${CONFIGURATION} archive"
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -clonedSourcePackagesDirPath "$SP_DIR" \
    -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    clean archive
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "[archive-smoke] ERROR: archive was not created at $ARCHIVE_PATH" >&2
  exit 1
fi

case "$archive_kind" in
  signed)
    if [[ "$SIGNING_MODE" == "manual" ]]; then
      verify_signed_archive
    else
      app_path="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' -type d -print -quit 2>/dev/null || true)"
      verify_app_bundle "$app_path" "automatic signed archive app"
    fi
    echo "[archive-smoke] Signed archive OK: $ARCHIVE_PATH"
    if [[ "$EXPORT_SIGNED_ARCHIVE" == "1" ]]; then
      export_signed_archive
    fi
    ;;
  *)
    echo "[archive-smoke] Unsigned archive OK: $ARCHIVE_PATH"
    ;;
esac

if [[ "$REQUIRE_SIGNED_ARCHIVE" == "1" || "$SIGNED_ARCHIVE" == "1" ]]; then
  report_signing_material "$(find_signing_identity_count)" "$(find_matching_profile_count)" || true
fi
