# TON Production Send Readiness (iOS)

Status: **BLOCKED / fail closed**. This document and
`config/ton-production-send-readiness.json` record the evidence that is still
missing; they do not authorize production TON send. The Release policy remains
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

## Enforced blocker

Run the executable contract directly:

```bash
bash ./scripts/test-ton-production-send-readiness-audit.sh
bash ./scripts/audit-ton-production-send-readiness.sh
```

The audit pins the blocked manifest digest, validates its exact schema, checks
the Release runtime kill switch and exact authenticated TonAPI origin, and
requires both PR and GitHub CI to run the adversarial self-test and audit. Any
evidence claim or enablement change therefore requires a deliberate, reviewed
update to the manifest, documentation, audit, tests, and runtime policy in the
same release change.
