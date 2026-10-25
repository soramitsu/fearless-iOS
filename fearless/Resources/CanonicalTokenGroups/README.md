# Shared portfolio configuration (IOSUX-5)

Byte copies of the files the root workspace repository owns (see its `docs/portfolio-contract.md`):

| Bundled file | Root source |
|---|---|
| `canonical-asset-groups.v1.json` | `config/token-groups/canonical-asset-groups.v1.json` |
| `testnet-chain-ids.v1.json` | `config/portfolio/testnet-chain-ids.v1.json` |
| `default-visible-at-zero.v1.json` | `config/portfolio/default-visible-at-zero.v1.json` |

`CanonicalTokenGroupCatalog`, `PortfolioTestnetChainList` and `PortfolioZeroDefaultList` read them
from the app bundle; `PortfolioUntrustedPriceList` reads `untrustedAssets` from the groups file. There
is no remote override in 4.2.0.

Never edit these copies by hand. Change the root file, then from the workspace root run

```sh
node scripts/sync-canonical-asset-groups.mjs --apps ios
```

which copies the files and rewrites the sha256 pins in
`fearlessTests/Common/Model/CanonicalTokenGroupCatalogTests.swift`. This README is not bundled.
