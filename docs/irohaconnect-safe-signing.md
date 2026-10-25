# IrohaConnect Safe Signing (iOS)

Status: **OFF in every build / fail closed.** `IrohaConnectReleasePolicy.production`
is `isEnabled: false`, with no environment, remote-config, or runtime override.
Only unit tests in Debug builds can use `IrohaConnectReleasePolicy.enabledForTests`.
This document records why IrohaConnect is off in 4.2.0 and the design that must
ship, and pass a security review, before the policy may be flipped.

## Why it is off

The 2026.8.34 TestFlight implementation signs bytes it cannot read, with a key
that controls real funds:

- `KeychainIrohaConnectAccountProvider.sign` calls
  `Curve25519.Signing.PrivateKey.signature(for:)` on `request.message` exactly as
  the dApp sent it (sign-raw, protocol request kind `1`).
- `IrohaConnectWireCodec.decodeSignRawEnvelope` decodes a `domain` string, but the
  domain is **not** part of the signed bytes. `IrohaConnectProtocolEngine` only
  checks that it equals `uranai.irohaconnect.contract-call-signature.v1`, and
  accepts messages of up to 32,768 bytes.
- The key is derived with `IrohaKeyDerivation` on
  `UniversalWalletDerivationPaths.irohaDefault` (`m/44'/617'/0'/0'`) for every
  Iroha registry entry. The chain discriminant (Taira 369, SORA Nexus 753) only
  changes the address encoding, so the Taira key **is** the SORA Nexus mainnet key.
- Iroha transaction signatures are Ed25519 over the 32-byte payload hash. A
  malicious or compromised dApp can send the hash of a mainnet transfer as
  `message` and receive a valid transfer signature. "Taira only" does not limit
  the risk.
- The prompt said "Sign Uranai contract calls only", which the code did not
  enforce. The copy now says "Signs data supplied by this app. Fearless can't
  decode it." so it stays truthful if the screen is ever reached again.

4.0.4 had no IrohaConnect, so turning it off is not a regression for App Store
users. Sessions only ever lived in memory, so there is nothing to migrate for
TestFlight users.

## What 4.2.0 does

| Entry point | Behaviour with the production policy |
|---|---|
| Settings → Connections | No IrohaConnect row (`ProfileViewModelFactory`, `ProfileViewController`); tapping a stale row is a no-op (`ProfilePresenter`) |
| `iroha://connect…` / `irohaconnect://connect…` links | `IrohaConnectURLHandler` still claims the link, so no other handler gets it. `IrohaConnectCoordinator.start(with:)` checks the policy **before** parsing: no socket, no `IrohaConnectSessionService`, no key access |
| Pairing QR / paste (landing page) | `presentLanding(from:)` checks the same policy; the QR and paste paths end in `start(with:)` |
| Any signature that still reaches the provider | `KeychainIrohaConnectAccountProvider.sign` throws `signingDisabled` before `materialLoader` runs, so key material is never loaded |

A link shows one calm sheet: "IrohaConnect isn't available in this version" /
"Fearless didn't connect to the app and nothing was signed. You can keep using
your wallet as usual." with a Close button. Details:

- The sheet appears only once the unlocked wallet interface is up
  (`ServiceCoordinator.setup()` calls `IrohaConnectCoordinator.shared.setup()`)
  and the app is active. A link that arrives during launch, behind the PIN
  screen, or while the app is in the background waits until then.
- At most one sheet: a link that arrives while a sheet is pending or on screen is
  ignored. If UIKit refuses the presentation, the sheet stays pending and is
  retried when the app next becomes active.
- The `Info.plist` URL schemes stay registered, so another app cannot claim
  `irohaconnect://`.
- The code, protocol vectors and tests stay in the tree for the work below.

## Design required before re-enabling

1. **No opaque signing.** Retire request kind `1` (sign-raw). Add two versioned
   kinds; old dApps get `unsupportedRequest` and fail closed.
   - `signTransaction{v2}(payload: NoritoBytes)`: the encoded Iroha
     `TransactionPayload`.
   - `signOffchainMessage{v2}(utf8Text ≤ 1 KiB)`.
2. **The wallet decodes and checks the payload itself.** Decode the
   `TransactionPayload` with an in-app Norito decoder pinned to the reviewed
   `../iroha` revision `d8544f1d4d3a` (the pin in `UniversalWalletRegistry`).
   Require all of:
   - `chain_id` equals the paired network. Taira only; SORA Nexus needs its own,
     separately reviewed release flag.
   - `authority` equals the selected account (i105).
   - TTL ≤ 10 minutes and `creation_time` within ±5 minutes of the device clock.
   - Every instruction is on an allowlist: Uranai `ExecuteTrigger` /
     contract-call instructions whose contract or trigger ids are listed in a
     bundled, reviewed `irohaconnect-allowlist.v1.json`.
   - **Hard deny** `Transfer`, `Mint`, `Burn`, `Register`/`Unregister` (account,
     asset, domain), `Grant`/`Revoke` (permission, role),
     `SetKeyValue`/`RemoveKeyValue` on accounts, `Upgrade`, `SetParameter`,
     `Log`, custom executor instructions, and any instruction the decoder does
     not know.
3. **The wallet computes the hash.** Compute `HashOf<TransactionPayload>`
   (Blake2b-256 with Iroha's last-bit convention, matching the pinned reference)
   from the decoded bytes and sign that. Never sign a hash supplied by the dApp.
4. **Off-chain messages are domain-separated.** Sign
   `Blake2b-256("iroha-connect|offchain|v2" ‖ u32 len(chainId) ‖ chainId ‖
   u32 len(origin) ‖ origin ‖ sessionId(32) ‖ u32 len(msg) ‖ msg)`. Producing a
   transaction payload hash from this needs a preimage attack, and the preimage
   never decodes as a `TransactionPayload`.
5. **The prompt shows the decoded call:** network, account, contract or trigger
   name, method, arguments (amounts formatted with the asset definition's
   precision and alias), expiry, and the app's claimed origin. "View raw bytes"
   sits behind a disclosure. **Reject** is the default and visually emphasised.
   A permission is scoped to one session and one contract.
6. **Tests:**
   - Golden vectors from the pinned Iroha repository: decode, hash, compare with
     the reference hash.
   - A property test that the policy rejects every instruction outside the
     allowlist.
   - `testOffchainDigestNeverEqualsSuppliedBytes`.
   - `testSignTransaction_whenChainIdIsNexus_thenRejected`.
   - `testSignTransaction_whenAuthorityDiffers_thenRejected`.
   - Fuzzing of the Norito decoder: malformed input throws, never crashes.

## Re-enable checklist

1. Items 1–6 above are implemented and their tests pass in Debug and Release
   (`scripts/test-matrix.sh`).
2. A security review signs off on the decoder, the allowlist, the hash
   computation and the prompt copy.
3. Flip `IrohaConnectReleasePolicy.production` in
   `fearless/Modules/IrohaConnect/IrohaConnectCoordinator.swift`. That single
   constant opens the coordinator, the Profile row and the account provider
   together. Update `IrohaConnectReleasePolicyTests` in the same change.
4. Remove the sign-raw path, not just hide it, so a later regression cannot bring
   opaque signing back.
