# Iroha Production Send Readiness (iOS)

Status: **BLOCKED / fail closed**. This is not an implemented production-send
claim. SORA Nexus remains `enabledByDefault: false`, and
`IrohaTransferService` defaults to `UnavailableIrohaTransferSigner()`. This
review does not link or materialize the SDK and does not approve changing the
wallet's minimum iOS version.

## Nexus wallet-smoke metadata boundary

The reviewed signing request now has an inert, value-typed transaction metadata
slot. Ordinary transfers always carry `.none`, which a future codec must omit
from the transaction. The only non-empty constructor is the operator evidence
hook `submitNexusWalletSmokeEvidence`; it takes an immutable snapshot and accepts
exactly these four string fields:

```json
{
  "evidence_role": "wallet-smoke",
  "route_governance_action_hash": "sha256:<64 lowercase nonzero hex characters>",
  "wallet_platform": "ios",
  "wallet_commit": "<40 lowercase nonzero git hex characters>"
}
```

Missing, extra, case-shifted, control-character, non-ASCII, malformed, and
all-zero placeholder values fail before signer or Torii invocation. The hook is
restricted to the exact canonical `sora:nexus:global` chain identity and the
exact canonical
`https://minamoto.sora.org` Torii endpoint. It is not part of
`TransferServiceProtocol`, does not enable Nexus, and does not install or link a
signer. The production default remains `UnavailableIrohaTransferSigner`, so even
valid evidence metadata fails closed before Torii until the independent SDK,
secret-lifecycle, hash-equality, finality, and funded-live gates below pass.

## Pinned archive evidence

The assessed integration target is the official Hyperledger Iroha release
[`v2.0.0-rc.2.1-fearless-mobile-sdk.3`](https://github.com/hyperledger/iroha/releases/tag/v2.0.0-rc.2.1-fearless-mobile-sdk.3),
commit `4f8cfbdd17aa6a3b049e619f23ec02501e5297b6`, published on
2026-06-25. Its Apple bridge delivery is:

- artifact: `NoritoBridge-v2.0.0-rc.2.1-fearless-mobile-sdk.3.xcframework.zip`
- SHA-256: `dc944af3dc98d37d349b9f95fe25b9e4a920f095db58adbcccc6354fc28ada4b`
- release-manifest size: `392660196` bytes
- 20 ZIP entries, `1396110349` expanded bytes, maximum entry `704780504`
  bytes, and expansion ratio `3.556`
- published slice hashes: iOS arm64
  `508b36e1ddc08d3c7488dfbb932d0e37f883908747296b6edab8465efbc3b77c`,
  simulator arm64/x86_64
  `b4ec44590205d173259f97a424702ace5d1fa70b469df578fc54a68fd2263b56`,
  and macOS arm64
  `3f13ce287c168b7103b368a67fbf22d1e1d8de0b1b345c8187fae1c206faa60a`

Independent ZIP path, entry-type, encryption, CRC, and size/ratio checks
passed. That proves bounded archive integrity only. The archive is larger than
the repository's `350000000`-byte mandatory review threshold and contains a
broad general-purpose native bridge, not a transfer-only boundary. It bundles
no LICENSE/NOTICE, SBOM, build provenance, or artifact attestation, and its Git
tag has no cryptographic signature. Source-to-binary reproducibility is not
proven.

## Package, platform, and binary-identity blockers

The app still supports iOS `14.1`; the tagged `IrohaSwift` package and assessed
binary require iOS `15.0`. Raising the product target is a separate product and
release decision, not an SDK integration detail.

At the official tag, `IrohaSwift/Package.swift` uses a path binary target at
`../dist/NoritoBridge.xcframework`, calls `fatalError` when it is absent, and
the tag contains only a symlink placeholder rather than a remote checksum
binary target. The package therefore cannot resolve directly from the tag.
After separate materialization, a tagged source compile with Xcode 26.5 / Swift
6.3.2 still fails because public default arguments in
`SorafsReferenceValidators.swift` call the private `currentEpochSeconds()`.

The tag's `NativeBridge.swift` hard-codes these expected slice hashes:

- iOS arm64: `26bb800e9dce021ef38306caef70dbba7928dd99c6612801fb1bbc520b52b7a9`
- simulator: `d0f651e6dc837bff7e92b05c9bf1e3a2988fc6995cabee6e3aaa269a01ecd1b5`
- macOS arm64: `d1dc2069532ff760e03ebf66fdd17811d8d7fa520dcd9f9048b61bbcbcffc3e2`

None matches the corresponding published release slice. The static-linked
package path also does not establish runtime digest enforcement. A checksum
valid outer ZIP therefore cannot establish that tagged Swift source and the
loaded native objects are the same reviewed build.

## Transaction hash parity blocker

For the tagged 576-byte `swift_transfer_asset_basic` fixture, the current
native compact External-entrypoint framing produces
`9756355bec7ca04a9e95025a0f24296a02118a5bf5989cc9c2cec0612bf76201`.
Fixed-width `u64` length framing instead produces
`c072426bffe62e12fc6b94a0c37ecf4eb2a805965964ce999e5183bddc9a1ce7`,
while the official tag's Swift parity manifest still records the raw signed
bytes hash
`6cc8aa66faa4b067c44831deaf225d8637ffd6daba05b11857b69a06a6b4279b`.
Those three values are intentionally distinct.

The active local Iroha worktree contains an unpublished correction that moves
the Swift entrypoint encoders and parity tests to compact framing. It is useful
diagnostic evidence only: it is not in the official tag, does not repair the
published XCFramework's provenance, and has not produced a reviewed release.

## Protocol and live-state blockers

The registry label `iroha3-taira` currently also flows into the signing
request's `chainId`. A route label must not be assumed to be the protocol
transaction chain identifier; an authoritative mapping is required before any
signer can be enabled.

The tag fixture uses asset definition `61CtjvNd9T3THAR65GsMVHr82Bjc`. A live
2026-07-11 Taira read instead reported native XOR as
`6TEAJqbb8oEPmLncoNiMRbLEK6tw`, scale `9`, with no alias. The wallet currently
returns a hard-coded zero fee. Production must resolve the canonical asset,
precision, and authoritative fee policy from reviewed live registry data; it
must not hard-code either fixture or observed identifier as timeless truth.

The deployed Taira node reported version `2.0.0-rc.2.0` at commit
`039af2d65e10b773be5031ab8fc07cf27b40e30d`, while the SDK tag is commit
`4f8cfbdd17aa6a3b049e619f23ec02501e5297b6`. Wire, registry, fee, and hash
compatibility across that revision gap is not proven.

## Secret and submission-integrity blockers

`IrohaTransferSigningRequest` carries mnemonic or seed material in an immutable
Swift `String`. Copies of that value cannot be reliably zeroized. A production
adapter needs a reviewed, minimal-lifetime secret boundary, local key/account
binding, best-effort cleanup of every mutable copy, and explicit acceptance of
any provider-owned residual copy.

The current unreachable submission seam prefers a locally supplied hash, then
falls back to either receipt hash, without requiring equality. It also returns
after submission without proving accepted and finalized status. Before
enablement, the locally computed canonical hash must exactly match Torii's
receipt, disagreement or missing hashes must fail closed, and accepted plus
finalized status must be independently recorded.

No funded Taira broadcast, funded Nexus broadcast, local/receipt hash-equality
record, accepted-status record, finalized-status record, or confirmed Nexus
production endpoint is present. Archive validation and local fixtures cannot
substitute for those live artifacts.

## Enforced blocker

The machine-readable state is
`config/iroha-production-send-readiness.json`. The blocker code remains
`apple_xcframework_review_and_materialization_required`. Run the executable
gates directly:

```bash
./scripts/test-iroha-production-send-readiness-audit.sh
./scripts/audit-iroha-production-send-readiness.sh
```

The audit fails if the manifest changes without review, Nexus becomes enabled
by default, the unavailable signer is replaced or bypassed, iOS 14.1 support is
silently raised, an IrohaSwift or NoritoBridge dependency/binary is added, the
known route-label, secret, zero-fee, or receipt-integrity risks are obscured,
negative signer tests disappear, the exact four-field wallet-smoke metadata
boundary weakens, or exact evidence markers drift.

`check-iroha-mobile-sdk-release-assets.sh` proves release-asset integrity only.
It does **not** make Iroha send production-ready. The unavailable signer and
disabled Nexus default must remain until every manifest exit criterion and the
funded live evidence gates pass in a newly reviewed release.
