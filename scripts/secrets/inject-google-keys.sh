#!/usr/bin/env bash
set -euo pipefail

INFO_PLIST="${1:-}"

if [[ -z "$INFO_PLIST" ]]; then
  INFO_PLIST="${BUILT_PRODUCTS_DIR:-}/${INFOPLIST_PATH:-}"
fi

if [[ -z "$INFO_PLIST" || ! -f "$INFO_PLIST" ]]; then
  echo "error: built Info.plist not found: $INFO_PLIST" >&2
  exit 1
fi

case "${CONFIGURATION:-}" in
  Release)
    DEFAULT_GOOGLE_CLIENT_ID="${WEB_CLIENT_ID_RELEASE:-}"
    DEFAULT_GOOGLE_URL_SCHEME="${FEARLESS_GOOGLE_URL_SCHEME_RELEASE:-}"
    ;;
  *)
    DEFAULT_GOOGLE_CLIENT_ID="${WEB_CLIENT_ID_DEBUG:-${WEB_CLIENT_ID_RELEASE:-}}"
    DEFAULT_GOOGLE_URL_SCHEME="${FEARLESS_GOOGLE_URL_SCHEME_DEBUG:-${FEARLESS_GOOGLE_URL_SCHEME_RELEASE:-}}"
    ;;
esac

GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-${FEARLESS_GOOGLE_TOKEN:-$DEFAULT_GOOGLE_CLIENT_ID}}"
GOOGLE_URL_SCHEME="${GOOGLE_URL_SCHEME:-${FEARLESS_GOOGLE_URL_SCHEME:-$DEFAULT_GOOGLE_URL_SCHEME}}"

if [[ -n "$GOOGLE_CLIENT_ID" && -n "$GOOGLE_URL_SCHEME" ]]; then
  /usr/libexec/PlistBuddy -c "Set :GIDClientID $GOOGLE_CLIENT_ID" "$INFO_PLIST" \
    || /usr/libexec/PlistBuddy -c "Add :GIDClientID string $GOOGLE_CLIENT_ID" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $GOOGLE_URL_SCHEME" "$INFO_PLIST"
  echo "Injected Google keys into built Info.plist for ${CONFIGURATION:-unknown} configuration"
else
  echo "Google keys not provided; skipping injection (non-fatal)."
fi
