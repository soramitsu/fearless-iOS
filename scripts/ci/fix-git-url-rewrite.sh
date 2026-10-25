#!/usr/bin/env bash
set -euo pipefail

# Fix broken Git URL rewrite entries that were added with unexpanded bash expressions
# e.g., url."${GH_PAT_READ:+https://${GH_PAT_READ}@github.com/}".insteadOf "https://github.com/"
# These cause: fatal: protocol '${GH_PAT_READ:+https' is not supported

echo "==> Inspecting global Git URL rewrites (url.*.insteadOf)"
/usr/bin/git config --global --get-regexp '^url\..*\.insteadOf$' || true

echo "==> Removing any rewrite keys that contain unexpanded \${...} patterns"
while read -r key val; do
  if [[ "$key" =~ \$\{ ]]; then
    echo "Removing broken rewrite: $key -> $val"
    /usr/bin/git config --global --unset-all "$key" || true
  fi
done < <(/usr/bin/git config --global --get-regexp '^url\..*\.insteadOf$' 2>/dev/null || true)

echo "==> Removing rewrites that blindly map https://github.com/ when not needed"
while read -r key val; do
  if [[ "$val" == "https://github.com/" ]]; then
    echo "Removing rewrite: $key -> $val"
    /usr/bin/git config --global --unset-all "$key" || true
  fi
done < <(/usr/bin/git config --global --get-regexp '^url\..*\.insteadOf$' 2>/dev/null || true)

echo "==> Final global URL rewrites:"
/usr/bin/git config --global --get-regexp '^url\..*\.insteadOf$' || echo "(none)"

cat <<'NOTE'

If you need to add a GitHub PAT rewrite for private pods on trusted branches, do it safely:

  if [ -n "$GH_PAT_READ" ]; then
    /usr/bin/git config --global url."https://${GH_PAT_READ}@github.com/".insteadOf "https://github.com/"
  fi

Avoid using Bash parameter expansion in the key (e.g., ${VAR:+...}) — Git will treat it as a literal protocol.

NOTE

