# TonAPI

The tonapi.io REST client used for TON balances, jettons, history, emulation and sending.
It is generated in this repository and replaces `tonkeeper/ton-api-swift` 0.1.7, which has no
licence file (all rights reserved). Owner's order, 2026-11-07: "don't use any closed source
libraries. make everything you need here in this repo, open source".

## Sources

- `openapi/openapi.yml`: the tonapi OpenAPI specification from
  [tonkeeper/opentonapi](https://github.com/tonkeeper/opentonapi) `api/openapi.yml`, MIT
  (`openapi/LICENSE`). SHA-256 `0fc4985f8f2af3bda108598afce52b4f52a66a1cbe86c727fcac9337c63de752`,
  the same bytes ton-api-swift 0.1.7 generated from. Content:
  - opentonapi `57f3549abe6e39376fa3f325250bde723bfcf644` (2023-12-22) as the base;
  - definitions opentonapi added later: `/v2/status` and `ServiceStatus` (`8e84bfb3ed`, `df80dae3e9`,
    2024-02-08), `ReducedBlock` (`3b5624c599`, 2024-06-24), and the jetton transfer payload
    endpoint, `JettonTransferPayload` and the jetton balance `extensions`/`lock` fields
    (`6cae372466`, 2024-07-31);
  - five string fields without their `enum` lists (`auction_type` twice, `dex`, the inscription
    `type` and `compiler`), so a value tonapi adds later still decodes.
- `Sources/TonAPI/Client.swift` and `Types.swift`: output of Apple's
  [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) 0.3.1 (Apache-2.0)
  with `--mode types --mode client`, built at the dependency revisions in
  `scripts/deps/tonapi-generator/Package.resolved`. `scripts/deps/tonapi-generator/postprocess.py`
  then drops the required `Action._type` property, so an action kind tonapi adds later cannot
  fail a whole history page.

## Verification (2026-11-07)

The regenerated `Client.swift` (SHA-256 `f19c75bb…301c1`) and post-processed `Types.swift`
(SHA-256 `9bd3f098…61514`) are byte-identical to the files in ton-api-swift 0.1.7 that the app
compiled before, so the app's TON code and behaviour are unchanged.

Rerun the check with `scripts/deps/regenerate-tonapi.sh`. It downloads the generator and its
dependencies from GitHub and fails if the committed sources differ from fresh output.
