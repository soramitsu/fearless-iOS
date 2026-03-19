#!/usr/bin/env bash
set -euo pipefail

# Helper script that configures local Git credentials so CocoaPods/SPM can
# fetch private dependencies (FearlessKeys, SSFAssetManagmentStorage, etc.).
# Usage:
#   GH_PAT_READ=ghp_xxx scripts/secrets/setup-private-pods.sh
# or run without GH_PAT_READ to be prompted interactively.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.private"

info()  { echo "[private-pods] $*"; }
error() { echo "[private-pods][error] $*" >&2; }

TOKEN="${GH_PAT_READ:-}"
if [[ -z "$TOKEN" ]]; then
  read -rp "GitHub Personal Access Token (with repo read access): " TOKEN
fi

if [[ -z "$TOKEN" ]]; then
  error "Token is empty. Aborting."
  exit 1
fi

info "Configuring Git to use the provided token for https://github.com/"
git config --global url."https://${TOKEN}@github.com/".insteadOf "https://github.com/"

info "Writing local env helper to $ENV_FILE (adds INCLUDE_FEARLESS_KEYS=1)"
cat > "$ENV_FILE" <<'EOF'
# Source this file (e.g. `source .env.private`) before running pod install/dev-setup.
export INCLUDE_FEARLESS_KEYS=1
EOF

info "Done. Next steps:"
info "  1) source $ENV_FILE (or add it to your shell init)"
info "  2) run: pod install"
info "  3) run: scripts/dev-setup.sh"
info "You can remove the token by running:"
info "  git config --global --unset-all url.\"https://${TOKEN}@github.com/\".insteadOf"
