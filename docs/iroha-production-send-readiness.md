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

## Protocol profile and live-state blockers

The first-release profile now uses protocol chain id
`fc56984b-2be7-431d-840e-21514d1883f0` directly; the retired route label is not
accepted as a signing identity. Asset selectors are canonical Base58 end to
end. The profile identifies native XOR by canonical Base58 definition id
`6TEAJqbb8oEPmLncoNiMRbLEK6tw`; `name#domain` aliases are not accepted at any
asset-definition boundary. Torii definitions are checked on every
balance/history read against the canonical symbol `XOR`, scale 9, and 9-decimal
profile. The pre-rollout live observation did not expose a scale, so a live
`spec.scale` of 9 must be recorded after rollout before release.

Successful reads carrying any fanout header are accepted only when all six
attempted, succeeded, failed, denied, unavailable, and not-found headers are
present and every attempted route succeeds. Partial or malformed fanout responses, truncated pages,
definition mismatches, and inexact quantities propagate as errors and cannot
be reconciled as zero balances or empty history. Fee estimation fails closed
with typed `IrohaTransferFeeError.authoritativePolicyUnavailable` instead of
displaying a fabricated zero fee; authoritative fee policy remains a production
blocker.

The 2026-08-23 read-only live observation reports build commit
`7efcc118eb50e3369d004d092f9b9d0b4d31ac52`, only six blocks and two peers,
roughly 41 minutes without chain progress, no reported chain id, and an
absolute manifest-path disclosure. Canonical XOR reads reached only one of
five fanout routes and returned a null scale; none of the four committed
validator DNS names resolved. This mobile snapshot is fail-closed context; the
workspace-root live gate remains deployment authority.

## Secret and remaining send blockers

`IrohaTransferSigningRequest` carries mnemonic or seed material in an immutable
Swift `String`. Copies of that value cannot be reliably zeroized. A production
adapter needs a reviewed, minimal-lifetime secret boundary, local key/account
binding, best-effort cleanup of every mutable copy, and explicit acceptance of
any provider-owned residual copy.

The unreachable submission seam invokes MCP
`iroha.transactions.submit_and_wait` with `body_base64`, a canonical locally
computed odd-marker hash, and `terminal_statuses: ["Applied"]`. It accepts
success only when the top-level hash, `tx_hash`, receipt `entrypoint_hash`, and
final-status hash all equal the local hash and both terminal kinds are
`Applied`. `Rejected`, `Expired`, non-Applied results, mismatched hashes, unknown
payloads, and timeout fail closed. Funded live evidence is still required before
the unavailable production signer can be replaced.

No funded Taira broadcast, funded Nexus broadcast, all submit-and-wait hash-equality
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
known chain-identity, secret, fee-unavailability, or receipt-integrity risks are obscured,
negative signer tests disappear, the exact four-field wallet-smoke metadata
boundary weakens, or exact evidence markers drift.

`check-iroha-mobile-sdk-release-assets.sh` proves release-asset integrity only.
It does **not** make Iroha send production-ready. The unavailable signer and
disabled Nexus default must remain until every manifest exit criterion and the
funded live evidence gates pass in a newly reviewed release.
