#!/usr/bin/env bash
set -euo pipefail

# Post-process generated Cuckoo mocks to resolve ambiguous symbols between
# app module (fearless) and SSF packages by module-qualifying types/protocols.
# Usage: scripts/tests/patch-mocks.sh [files...]

TARGETS=()
if [ "$#" -eq 0 ]; then
  while IFS= read -r -d '' f; do TARGETS+=("$f"); done < <(find fearlessTests/Mocks -name '*.swift' -print0)
else
  for arg in "$@"; do TARGETS+=("$arg"); done
fi

for f in "${TARGETS[@]}"; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  # Only strip SSF imports from the two large generated bundles
  if [[ "$base" == "CommonMocks.swift" || "$base" == "ModuleMocks.swift" ]]; then
    /usr/bin/sed -E -i '' \
      -e '/^import SSF[A-Za-z0-9_]*/d' \
      -e '/^typealias[[:space:]]+MetaAccountModel[[:space:]]*=/d' \
      -e '/^typealias[[:space:]]+ChainAccountResponse[[:space:]]*=/d' \
      "$f"
  fi
  # Qualify ambiguous app types and protocols
  perl -0777 -i -pe 's/(?<!\.)\bMetaAccountModel\b/fearless.MetaAccountModel/g;
                     s/(?<!\.)\bManagedMetaAccountModel\b/fearless.ManagedMetaAccountModel/g;
                     s/(?<!\.)\bChainAccountResponse\b/fearless.ChainAccountResponse/g;
                     s/(?<!\.)\bSNAddressType\b/fearless.SNAddressType/g;
                     s/(?<!\.)\bChainRegistryProtocol\b/fearless.ChainRegistryProtocol/g;
                     s/(?<!\.)\bConnectionPoolProtocol\b/fearless.ConnectionPoolProtocol/g;
                     s/(?<!\.)\bChainConnection\b/fearless.ChainConnection/g;
                     s/(?<!\.)\bRuntimeProviderPoolProtocol\b/fearless.RuntimeProviderPoolProtocol/g;
                     s/(?<!\.)\bRuntimeProviderProtocol\b/fearless.RuntimeProviderProtocol/g;
                     s/(?<!\.)\bRuntimeSyncServiceProtocol\b/fearless.RuntimeSyncServiceProtocol/g;
                     s/(?<!\.)\bRuntimeVersion\b/fearless.RuntimeVersion/g;
                     s/(?<!\.)\bChainModel\b/fearless.ChainModel/g;
                     s/(?<!\.)\bChainAsset\b/fearless.ChainAsset/g;
                     s/(?<!\.)\bAssetModel\b/fearless.AssetModel/g;
                     s/(?<!\.)\bSchedulerProtocol\b/fearless.SchedulerProtocol/g;
                     s/(?<!\.)\bSchedulerDelegate\b/fearless.SchedulerDelegate/g;
                     s/(?<!\.)\bRuntimeMetadataItem\b/SSFModels.RuntimeMetadataItem/g;' "$f"
  # Restore clean alias LHS if our qualifier hit typealias lines
  /usr/bin/sed -E -i '' -e 's/^typealias[[:space:]]+fearless\.MetaAccountModel/typealias MetaAccountModel/' \
                       -e 's/^typealias[[:space:]]+fearless\.ChainAccountResponse/typealias ChainAccountResponse/' "$f"
done

echo "Patched ${#TARGETS[@]} mock files."
