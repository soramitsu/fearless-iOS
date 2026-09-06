# TestFlight 4.2.0 (2026.9.6)

Published on 2026-09-06. Apple accepted and processed the signed archive; the
existing `App Store Connect Users` internal group shows this build as **Testing**
for its six testers. Complete test notes are saved.

- [App Store Connect build](https://appstoreconnect.apple.com/teams/69a6de8e-8bb9-47e3-e053-5b8c7c11a4d1/apps/1537251089/testflight/ios/d3278028-7aa4-4f0a-b19d-2c12f7e3f50b)
- Release source commit: `645c15373bef2c9e384abf4f28deaef34007e7bf`.
- Signed archive: `build/testflight-2026.9.6-signed-release-pass3/fearless.xcarchive`.
- Signed audit: `build/testflight-2026.9.6-signed-release-pass3/signed-archive-audit.json`.
- Publication attestation: `build/release-preparation-20260906/testflight-publication-attestation.json`.

## Included changes and qualification

This candidate includes the completed legacy upgrade preservation fixes, native
TON/Jetton/TonConnect restoration, and the tested accessibility/layout changes.
The app, test, and package source inventory is carried from the qualified working
copy; the release-specific project changes set the build number, synchronize the
SwiftPM lockfiles, and correct build-time service configuration handling.

- iOS regression inventory: 526 unique passing Release tests.
- Repository-owned TonSwift SDK: 41 passing tests.
- Release identity contract: 43 passing cases; signed artifact contract: 59.
- TON readiness audit: 84 passing mutation cases; the general production-send
  gate remains disabled and the reviewed legacy native-account exception remains
  bound to the original key and address.
- Fastlane publishing tests: 18 passing tests / 36 assertions with pinned 2.238.0.
- Real Xcode production identity preflight passed for this version/build.
- Service configuration generation: 10 passing tests, including compiled Swift
  literal round trips and atomic write failure recovery.
- Service configuration audit and actual project-phase injection: 33 passing
  tests; missing and placeholder configuration is rejected.
- Final combined network/history/recovery run: 69 passing Release tests, no
  failures or skips; includes the manual-refresh recovery regression.
- Production EVM node selection: 14 passing integrated Release tests (12 new
  selector cases plus 2 existing chain-registry lifecycle checks).
- Device-upgrade evidence audit: 20 passing tests; startup capture: 39 passing
  tests, including the new supported build.

The authenticated App Store Connect preflight found build 2026.9.6 unused. The
existing internal group is `App Store Connect Users`, with automatic distribution
of Xcode builds enabled. Recheck build uniqueness immediately before archiving.

## Production configuration and service recovery

The local `CIKeys.generated.swift` in every available iOS working copy contained
Boolean placeholders. The legacy Sourcery invocation passed unset environment
variables as empty `--args` assignments, which generated quoted Boolean values.
Historical release source inspection established the actual production mapping:
iOS 4.1.0 pinned FearlessKeys 0.1.5 and unconditionally used its TON key and native
Google identity despite their legacy Debug enum names. The native Google build
phase injected that same client/callback pair. TON mainnet/testnet and
WalletConnect credentials passed live read-only checks with invalid controls.
Production Alchemy settings were recovered from the exact signed, published
Chrome 3.0.5 artifact and passed Ethereum, Polygon, Optimism and Arbitrum history
probes. These four catalog routes now use Alchemy. Avalanche uses the verified
public Routescan Etherscan-compatible API with bounded pagination. Both adapters
validate provider responses and preserve native asset identifiers. Legacy
OKLink keys were rejected and are omitted.

The full catalog has nine former OKLink routes. BNB Mainnet is not enabled on the
existing Alchemy account; Kaia and X Layer require replacement indexer credentials
that are not available in the release sources. History failures expose working
Retry and View on explorer actions, stop loading indicators, retain loaded rows,
and discard completions for a previously selected account or network. API
rejections never become an apparently empty history. Chain 196 uses the mainnet
explorer despite its stale catalog testnet URL. Polygon zkEVM was retired by its
operator on 2026-07-01; its legacy accounts and keys remain preserved.

Enabling BNB Mainnet on the existing Alchemy app and provisioning replacement
Kaia/X Layer history access remain service-operations follow-ups. They do not
block wallet startup, upgrade, account access, or the explicit explorer recovery.

The generator now renders the reviewed template from the existing environment
variable names, escapes Swift literals, leaves unset settings empty, writes the
ignored output atomically with mode 0600, and never places credentials in process
arguments or diagnostics. Google identity injection only changes the built app;
it no longer rewrites tracked plist or xcconfig files. The helper and build-phase
input use `TARGET_BUILD_DIR`, which correctly handles Xcode archive app symlinks
without allowing writes outside the actual target product. Archive preflight rejects
missing/placeholder active service settings, and postflight verifies unchanged
configuration and the actual archived Google OAuth identity. Receipts contain
hashes and presence information, never setting values.

The retired Blast node credentials are now optional: EVM node selection skips
exact Blast provider hosts and falls back deterministically to eligible nodes
already in the chain catalog. Explicit supported custom HTTPS/WSS selections,
paths and query strings are preserved without appending unrelated provider keys.
No account identity or stored node setting is rewritten by this fallback.

The active ignored production configuration is provisioned from these
verified release sources. The TON generator also accepts the deployed Jenkins
`FL_IOS_TON_API_KEY` alias and rejects conflicting aliases. Retired Blast and
rejected OKLink credentials are not copied into the candidate.

Production CI configuration is loaded through the existing ignored
`fearless/env-vars.sh` and rendered into the ignored generated Swift file.
Regeneration preserves identical files so incremental builds remain valid. The native Google OAuth client and
callback must match; the template's web client identifier may be a separate
server client. Do not commit service configuration.

## Publication verification

All 69 final Release tests passed with no failures or skips. The production
archive passed the exact signing identity, entitlements, default Keychain access,
legacy storage models, service configuration and symbol coverage audits. Its tree
SHA-256 is `18cdd063ad66f956529cc3e3afc6b5fe7d92e1b0715c779b1e3753830bca501d`.

Xcode Organizer uploaded a copy of the audited archive with version/build
management disabled and the reviewed production certificate/profile selected.
Apple processing completed, and the existing internal group's build list shows
`4.2.0 (2026.9.6)` as `Testing`. The original audited archive remains unchanged.

Signed-device upgrades in place from historical releases remain the acceptance
gate before broader release. The local synthetic qualification does not replace
that device check, and TestFlight upload alone does not establish it.
