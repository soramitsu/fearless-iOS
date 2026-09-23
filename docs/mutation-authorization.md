# Signed mutation authorization integration

The iOS implementation consumes the shared FWMA1 contract. It verifies pure
Ed25519 signatures with bundled keys, canonical closed payloads, exact bundle
identity and reviewed build ordinal, policy and route digests, capability flags,
revision and expiry. The maximum signed lifetime is 900 seconds, with a separate
continuous-time deadline capped at 900 seconds even under tolerated clock skew.

`FeatureToggleProvider` refreshes the existing configuration every 300 seconds.
The signed field is `mutation_authorization`; both plain JSONDecoder and the
production GithubJSONDecoder normalization are covered. The pinned SSFNetwork
factory bypasses local and remote caches. Missing, invalid or failed refreshes
invalidate new-feature authorization. The current policy also checks expiry at
use, so an old in-memory enable bit cannot outlive its token.

Demeter, Polkamarkt and XCM mutation flags require signed authority on iOS.
Existing Polkaswap behavior and unrelated wallet/UI preferences retain their
historical controls. Read-only route discovery remains a separate qualification
item, including navigation paths that still check the old mutation flag.

High-water revision, payload digest and maximum observed wall time are stored
atomically in a separate nonsynchronizing, device-local Keychain item. No wallet
key or historical storage namespace is changed. Every process starts denied
until a verified network response arrives. Locked/corrupt storage denies new
mutations. An ambiguous write poisons the authority until restart and reload;
it cannot fall back to a stale in-memory revision. Failed refreshes invalidate
leases but retain the same-payload continuous-time deadline.

## Unfinished production prerequisites

No production authority key, approved policy or route inventory has been invented
or bundled. The loader expects `mutation_authorization_trust.json`,
`mutation_authorization_policy.json`, `mutation_route_manifest.json`, and the
exact `mutation_route_inventory.json` input. Missing resources deny authorization.
The release-manifest work must generate that inventory from all compiled
executable/discovery-only route definitions, canonical assets, precision and
call descriptors, and independently bind it to reviewed shipping source.
Hashes and filenames alone do not establish that semantic coverage.

The tested lease API binds authority generation, capability and exact transaction
intent, and serializes its final check with a synchronous transport enqueue.
The existing async extrinsic/signing/network implementations still need to carry
those leases through actual key access, signing and final send. A check at the
caller before `service.submit` is insufficient. No enabled-feature qualification
is claimed until those integrations, adversarial tests and actual device/funded
receipts pass. Independent release security review remains required.

## Development verification

Android and iOS use the identical nine test-only Ed25519 vectors. They include
valid enabled/disabled payloads, revision change, expiry, wrong audience/version
and signature failures. Additional Swift tests exercise canonical encoding,
manifest substitution, clock rollback, process restart, storage failure and
revocation during enqueue. Shared fixture SHA-256:
`59b43ebefb1ef0e79858b78f4266c3d2265b7e03d4041c1b3e936910b2eee49d`.

Source and result digests for the final local Release verification are retained
under `build/production-reconciliation-20260922`. These local tests do not replace
protected-branch CI, an independent review or Apple-delivered upgrade acceptance.

Final local Release verification passed 103 tests with zero failures/skips:
19 authorization tests, 9 configuration tests and 75 Main Tab tests. The
implementation receipt is `build/production-reconciliation-20260922/mutation-authorization-implementation.json`.
After that run, the build formatter changed from automatic source mutation to
verification-only; its own check passed on 2,865 unchanged Swift files. A final
shipping manifest must still qualify a clean complete build after all integration.
