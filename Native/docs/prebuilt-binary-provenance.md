# Prebuilt binary provenance

Three of the wallet's native binaries were already accounted for:

- `sr25519lib` is rebuilt from pinned Rust source; see
  [sr25519-native-signing.md](sr25519-native-signing.md).
- `libed25519` and `blake2lib` are now built from pinned C sources; see
  [ed25519-blake2-native-provenance.md](ed25519-blake2-native-provenance.md).

`sorawallet.xcframework`, a closed-source Kotlin/Native framework built in
February 2024 from an unpublished revision of `soramitsu/x-networking`, was
removed on 2026-11-07. The wallet used it only to read Polkaswap pool
strategic-bonus APY. That query is now plain Swift in
`Sources/SSFPolkaswap/PolkaswapAPYWorker.swift`, sent to the Soramitsu indexer
(`https://pi.soramitsu.io/graphql`) that the wallet already uses for SORA
prices. The framework's configured SubQuery endpoint
(`api.subquery.network/sq/sora-xor/sora-prod`) answered HTTP 503 on that date.

The prebuilt `yttrium` libraries (`libyttrium.xcframework` and
`libyttrium-utils.xcframework`) that came in through `reown-swift` were removed
with it on 2026-11-07: `reown-swift` is under the WalletConnect Community
License, which is not open source. The wallet now speaks WalletConnect with its
own open-source client, `Packages/FearlessWalletConnect` (see
`docs/walletconnect-protocol.md`), which uses only Apple's system frameworks.
