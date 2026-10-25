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
                     s/(?<!\.)\bRuntimeProviderProtocol\b/SSFRuntimeCodingService.RuntimeProviderProtocol/g;
                     s/(?<!\.)\bRuntimeSyncServiceProtocol\b/fearless.RuntimeSyncServiceProtocol/g;
                     s/(?<!\.)\bRuntimeVersion\b/fearless.RuntimeVersion/g;
                     s/(?<!\.)\bChainModel\b/SSFModels.ChainModel/g;
                     s/(?<!\.)\bChainAsset\b/SSFModels.ChainAsset/g;
                     s/(?<!\.)\bAssetModel\b/SSFModels.AssetModel/g;
                     s/(?<!\.)\bChainAccountInfo\b/fearless.ChainAccountInfo/g;
                     s/fearless\.ChainModel/SSFModels.ChainModel/g;
                     s/fearless\.ChainAsset/SSFModels.ChainAsset/g;
                     s/fearless\.AssetModel/SSFModels.AssetModel/g;
                     s/SSFModels\.ChainAccountInfo/fearless.ChainAccountInfo/g;
                     s/fearless\.RuntimeProviderProtocol/SSFRuntimeCodingService.RuntimeProviderProtocol/g;
                     s/(?<!\.)\bSchedulerProtocol\b/fearless.SchedulerProtocol/g;
                     s/(?<!\.)\bSchedulerDelegate\b/fearless.SchedulerDelegate/g;
                     s/(?<!\.)\bRuntimeMetadataItem\b/fearless.RuntimeMetadataItem/g;
                     s/SSFModels\.RuntimeMetadataItem/fearless.RuntimeMetadataItem/g;
                     s/__defaultImplStub!\.createRepository\(\)/DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<fearless.MetaAccountModel>).self)/g;
                     s/__defaultImplStub!\.createAccountRepository\(for: p0\)/DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<fearless.MetaAccountModel>).self)/g;' "$f"
  # Restore clean alias LHS if our qualifier hit typealias lines
  /usr/bin/sed -E -i '' -e 's/^typealias[[:space:]]+fearless\.MetaAccountModel/typealias MetaAccountModel/' \
                       -e 's/^typealias[[:space:]]+fearless\.ChainAccountResponse/typealias ChainAccountResponse/' "$f"

  if [[ "$base" == "CommonMocks.swift" || "$base" == "ModuleMocks.swift" ]]; then
    if ! /usr/bin/grep -q '^import SSFModels' "$f"; then
      /usr/bin/sed -i '' '2a\
import SSFModels
' "$f"
    fi
    if ! /usr/bin/grep -q '^import SSFRuntimeCodingService' "$f"; then
      /usr/bin/sed -i '' '2a\
import SSFRuntimeCodingService
' "$f"
    fi
  fi
done

echo "Patched ${#TARGETS[@]} mock files."
