# RuntimeMetadataFixtures

Runtime metadata of live chains for the call encoding tests (`SSFUtilsTests`, `SSFXCMTests`).
Test support only: no product of the package depends on this target.

Each `<chain>-<specVersion>.hex` is the `state_getMetadata` result of that chain, cut down by
`scripts/trim-runtime-metadata.py` to the call enums of the pallets the tests use. The call enums
are untouched (pallet name, module index, call names, argument types, variant indexes with their
gaps) and so is every type they reach. Storage, events, errors, constants, signed extensions and
documentation are dropped, and generic parameters pointing outside the kept types are cleared.
That is enough to encode and decode calls and nothing else.

`<chain>-<specVersion>.manifest.json` records where a file came from (genesis hash, spec version,
size and SHA-256 of the metadata it was cut from) and the call table of the kept pallets as read
from the untouched metadata, so a test can compare the code under test with something it did not
produce.

| File | Chain | Pallets |
|---|---|---|
| `polkadot-asset-hub-2005000` | Polkadot Asset Hub | Balances, PolkadotXcm |
| `polkadot-2005000` | Polkadot | XcmPallet |
| `acala-2370` | Acala | XTokens, PolkadotXcm |
| `sora-134` | SORA | BridgeProxy |
| `liberland-34` | Liberland | SoraBridgeApp |

## Refreshing a file

```sh
curl -sS -H 'Content-Type: application/json' \
  -d '{"id":1,"jsonrpc":"2.0","method":"state_getMetadata","params":[]}' \
  https://polkadot-asset-hub-rpc.polkadot.io -o metadata.json

python3 scripts/trim-runtime-metadata.py --metadata metadata.json \
  --pallet Balances --pallet PolkadotXcm --chain "Polkadot Asset Hub" \
  --genesis-hash 0x68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f \
  --spec-version 2005000 --fetched YYYY-MM-DD \
  --out Sources/RuntimeMetadataFixtures/Resources/polkadot-asset-hub-2005000.hex \
  --manifest Sources/RuntimeMetadataFixtures/Resources/polkadot-asset-hub-2005000.manifest.json
```

A refreshed file changes call tables only when the runtime did. The tests that spell out expected
bytes name the call by pallet and call name, so they keep holding as long as the runtime keeps the
call; a renumbered call shows up as a failing byte vector, which is the point.
