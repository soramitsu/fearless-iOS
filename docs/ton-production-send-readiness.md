# TON Production Send Readiness (iOS)

Status: **BLOCKED / fail closed**. This document and
`config/ton-production-send-readiness.json` record the evidence that is still
missing for general universal-wallet TON send. The Release policy remains
`TonProductionSendReleasePolicy(isEnabled: false)`, with no environment,
remote-config, or runtime override.

## Required release evidence

One immutable, independently reviewed evidence bundle must satisfy every item
below before the runtime policy can be reconsidered:

1. **Wallet V4R2 fee parity.** For the identical Wallet V4R2 template, record
   exact `totalFeeNanotons` parity between TonAPI unsigned emulation at
   `/v2/traces/emulate?ignore_signature_check=true` and signed emulation at
   `/v2/wallet/emulate`. The only acceptable alternative is a separately
   reviewed and attested local-TVM or quote mechanism that does not trust an
   unsigned signature-bypass result as authorization.
2. **Endpoint and credential provisioning.** Attest that the Release binary's
   exact origin is `https://tonapi.io`, the registry resolves to that reviewed
   origin, and a nonempty visible-ASCII credential of at most 4096 bytes is
   provisioned through the reviewed release-secret path without committing or
   logging the credential.
3. **Funded mainnet transfer.** Record a real funded mainnet Wallet V4R2 transfer
   with unsigned emulation, signed emulation, broadcast, exact-hash on-chain
   reconciliation, exact fee verification, and recipient-credit verification.
   Unit tests, fixtures, testnet transactions, and screenshots alone do not
   satisfy this criterion.
4. **Expired bearer recovery.** Approve either a finalized-chain absence
   procedure or an explicit audited quarantine and recovery procedure before
   an expired, never-confirmed bearer record may release its sender. The current
   intentional behavior is to block that sender indefinitely rather than guess
   that the message is absent.

The local recovery coordinator now restores a persisted bearer from its transient
retry state if the current reviewed endpoint is missing or differs from the
stored quote origin. An expired bearer remains in the journal, blocks any new
intent, and can be reconciled again in the same process after the endpoint is
corrected. Repeated `notFound` responses do not release the sender or authorize
a broadcast. This is a fail-closed continuity fix, not the audited quarantine
and release procedure required above; it supplies no finalized-chain absence,
fee-parity, funded-transfer, or live TonAPI evidence.

## Enforced blocker

Run the executable contract directly:

```bash
bash ./scripts/test-ton-production-send-readiness-audit.sh
bash ./scripts/audit-ton-production-send-readiness.sh
```

The audit pins the blocked manifest digest, validates its exact schema, checks
the general Release runtime kill switch, exact authenticated TonAPI origins, and the validated legacy-only path, and
requires both PR and GitHub CI to run the adversarial self-test and audit. Any
evidence claim or enablement change therefore requires a deliberate, reviewed
update to the manifest, documentation, audit, tests, and runtime policy in the
same release change.


## Released native-wallet compatibility

Build `4.2.0 (2026.9.6)` retains the user-authorized pre-4.2 native TON, Jetton and TonConnect functions. This is a separate typed legacy-account path; it does not enable `TonProductionSendReleasePolicy.production` or claim the missing funded-mainnet evidence above. The original V4R2 address must match the retained public key, and the original 64-byte native secret must match both its seed-derived public key and its stored suffix. Release send also binds that identity to the exact request sender/public key, requires the reviewed fee quote, and retains signed-message journaling and recovery.

The only reviewed signed-operation origins are exactly `https://tonapi.io` and `https://testnet.tonapi.io`. Released TonConnect requests preserve their explicit mainnet/testnet network through quote, authorization, signing and journal recovery. No registry node or arbitrary HTTPS origin receives a credential or signed operation. The audit's adversarial fixtures reject an extra origin, missing testnet compatibility, an insecure or disguised testnet origin, unqualified account routing, mismatched contract/address/private key, and removed network binding. The immutable general-enablement manifest remains unchanged and blocked. Local compatibility evidence is recorded in `legacy-upgrade-audit-20260906.md` (526 app cases and 41 SDK cases); no live transfer is claimed.
