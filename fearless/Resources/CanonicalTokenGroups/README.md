# App-owned portfolio configuration

These three JSON catalogs are owned by the iOS application:

- `canonical-asset-groups.v1.json`: reviewed asset groups and untrusted prices.
- `testnet-chain-ids.v1.json`: testnet identities.
- `default-visible-at-zero.v1.json`: default zero-balance visibility.

`CanonicalTokenGroupCatalog`, `PortfolioTestnetChainList`, and
`PortfolioZeroDefaultList` read them from the app bundle. There is no remote
override in 4.2.0. The registry source URL points to this application's owned
configuration; the frozen registry snapshot and approved membership remain
recorded in the catalogs and test fixtures.

Review changes here together with the byte commitments and behavioral tests in
`fearlessTests/Common/Model/CanonicalTokenGroupCatalogTests.swift`. No sibling
workspace checkout or shared-file synchronization script is required.
