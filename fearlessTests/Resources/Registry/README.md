# Registry snapshots

`chains_v13_owned_20261029.json` is a byte copy of `remote-config/production/chains/v13/chains.json` in this
repository on 2026-10-29: the chain list release builds read
(`https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/production/chains/v13/chains.json`,
`ApplicationConfig.chainsSourceUrl`). The cross-chain route tests use it. `CrossChainOwnedRemoteConfigTests` reads the
live files under `remote-config/production` instead, so every edit there is checked against the compiled route
registry.

- sha256: `373462d72052835bd02bf38018cb83478194bed96759c542120773aaae35d37b`
- 116 chains

`chains_v13_20261009.json` is a byte copy of
`https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/chains/v13/chains.json` fetched on 2026-10-09.
Release builds read that list until the app took its configuration into `remote-config/` (#1305). The repository is
archived and the app no longer reads it; the tests that pin this snapshot keep it for its content as of that day.

- sha256: `fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66`
- 116 chains

Do not edit snapshots in place. Add a new dated file instead, so tests that pin a snapshot keep their meaning.
This folder is an Xcode folder reference: files added here are bundled into `fearlessTests` under
`Registry/` without editing `project.pbxproj`.

`parity-cases.v1.json` is a byte copy of the root workspace file `config/portfolio/parity-cases.v1.json`
(sha256 `aab5746a3bf2aa75d661266c75ebea37138cde8aacd426e08508c06d2e5daa81`), the golden cases each app
reproduces (critique T-5). `CanonicalTokenGroupCatalogTests` pins its sha256; copy the root file again
and update the pin when the root cases change.

`liberland-metadata-spec34.hex` is the `state_getMetadata` result of `wss://mainnet.liberland.org` (runtime spec 34,
transaction version 2) read on 2026-10-24, and `liberland-chain-types-20261024.json` is Liberland's entry in the chain
types file of the same day. The app now reads that file from `remote-config/production/chains/all_chains_types.json`,
whose Liberland entry is identical. Together they let the reviewed bridge-call tests encode `SoraBridgeApp.burn`
exactly as the app's runtime does.

- `liberland-metadata-spec34.hex` sha256: `aafb8c9316a86815c4a43ca0b9db793701b73b34971ed4237c8fafe712b39c70`
- `liberland-chain-types-20261024.json` sha256: `ad6b2b9c0799548949a577920ca65ff9d65c519e87fcd6313435fdce3a8d930d`

`liberland-block-18541863.json` holds Liberland block 18,541,863 (runtime spec 34) as read on 2026-10-25: its
`chain_getBlock` extrinsics, its raw `System.Events` storage from `state_getStorage`, the index of its signed extrinsic
and that extrinsic's event names as polkadot.js decodes them. The dispatch watcher test decodes the same events with
the app's runtime.

- sha256: `ef135ea71901c71efc1a70627508857830bd6f5e0d2ea296a428b76eaa9bf53a`

`liberland-block-18541863-failed.json` keeps that block's events for its timestamp extrinsic and replaces the signed
extrinsic's events with one `System.ExtrinsicFailed` record carrying `DispatchError::Module { index: 81, error: 4 }`
(SoraBridgeApp's `WrongAmount`). No failed extrinsic appeared in the 44 blocks with signed extrinsics among the 20,000
blocks before 18,543,928, so the record was encoded with the spec 34 types and checked by decoding it with polkadot.js.

- sha256: `bd685fce9a5463ace10e6110e66026abea17a3f57335abbc3898c3da55524a26`
