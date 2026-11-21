# IrohaConnect Safe Signing (iOS)

Status: **ON** (`IrohaConnectReleasePolicy.production` is `isEnabled: true`). The wallet speaks
the current Iroha Connect v1, the protocol Torii relays on SORA Taira and that
`@iroha/iroha-js/connect-browser` and `@iroha/connect-widget` speak on the dApp side. It is a
port of the web wallet's implementation (fearless-wallet-web PR #1122,
`src/extension/background/extension-base/src/services/iroha-connect-service/`), and the unit
tests replay vectors that the web implementation and the upstream app SDK produced.

## What the wallet signs

The account's Ed25519 key signs exactly two kinds of bytes, both built by the wallet:

1. **The session approval preimage.** A tagged structure that starts with the domain
   `iroha-connect|approve|v1` and binds the NetworkId, the constraints hash, the sid, the app's
   and the wallet's X25519 keys, the account id, the hash of the requested permissions (when the
   app sent any) and the relay-auth hash `SHA-256("iroha-connect|relay-auth|v1" ‖ sid ‖ relay)`.
   It never decodes as a transaction payload.
2. **`HashOf<TransactionPayload>` of a reviewed transaction:** Blake2b-256 with Iroha's last-bit
   marker, computed by the wallet from the payload bytes the person just reviewed. Never a hash
   or bytes the dApp supplied.

Raw requests (`SignRequestRaw`) are answered with `SIGNING_KEY_REQUIRED` without signing:
they belong to an account's registered off-chain signing key, which Fearless accounts do not
have. A raw request can therefore never produce a transaction signature.

## The transaction review

`IrohaConnectTransactionReviewer` decodes the whole `SignRequestTx` payload into a review and
proves the review **is** the payload: `IrohaPayloadEncoder` encodes the decoded values again
with the canonical rules (and the input checks) of the iroha-js 0.0.3 browser transaction codec,
and the rebuild must reproduce the bytes exactly. Payload fields use canonical LEB128 lengths;
the `iroha.transfer` frame container keeps a u64 length.

A payload is reviewable only when:

- it targets the paired network: its NetworkId equals the pinned Taira genesis
  (`hash:4978D0BD…6D91#6774`). A payload for SORA Nexus or any other network is refused, so the
  shared Taira/Nexus key cannot be used across networks through Connect;
- its authority is the connected account, a single-key Ed25519 account, and the signing key is
  that account's key;
- the executable is one `Transfer::Asset` whose source owner is the authority, or a batch of
  contract calls (canonical `irohac1…` address, marked code hash, gas limit set);
- every account key is a strict Ed25519 point (canonical, not small-order, prime-order
  subgroup); quantities are positive, minimal and without fractional trailing zeros; the TTL is
  present; metadata is canonical JSON; and there are no proof attachments.

Anything else — instructions that need Iroha's native decoder, other executables, malformed or
non-canonical encodings — is refused with `UNSUPPORTED_TRANSACTION`, `INVALID_TRANSACTION`,
`WRONG_NETWORK` or `WRONG_ACCOUNT`, and the person sees one short notice that nothing was
signed.

The prompt shows the app's claimed name and origin (https, or http on loopback), the network,
the account, then the decoded call: amount and asset, the full destination, the scope, every
contract and method with an argument digest, the fee limits, gas limit and sponsor, the TTL,
metadata (control and bidirectional characters escaped) and the payload hash. Every signature
needs the wallet PIN or biometrics.

## Transport

- Links: `iroha://connect?…` and `irohaconnect://connect?…` with exactly `sid`, `network_id`,
  `app_pk`, `nonce`, `node`, `v=1`, `role=wallet`, `token` and `relay`. The sid must equal
  `blake2b-256("iroha-connect|sid|" ‖ NetworkId ‖ app_pk ‖ nonce)`, `node` must be exactly
  `https://taira.sora.org`, and retired links (`chain_id`) are refused. SORA Nexus links are
  refused until its NetworkId is pinned.
- Socket: `wss://taira.sora.org/v1/connect/ws?sid=…&role=wallet` with the subprotocol
  `iroha-connect.token.v1.<base64url(token)>`. Only binary frames are sent: **Torii closes a
  Connect socket on any text frame**, so the keepalive is a sequenced Connect Ping every 20 s.
- Frames use u64 length prefixes and element-frame every `[u8; 32]`. After approval, payloads
  travel in Norito NRT0 envelopes sealed with ChaCha20-Poly1305 under direction-separated keys
  (X25519 → HKDF-SHA256 session key → HKDF per direction with the sid-bound salt). Sequences are
  strict in both directions; a replayed, reordered or early frame ends the session.

Entry points: the IrohaConnect row in Settings → Connections (scan a QR code or paste a link)
and the same-device link. A link that arrives during launch or behind the PIN screen waits
until the unlocked wallet interface is up.

## Turning it off

`IrohaConnectReleasePolicy.production` in
`fearless/Modules/IrohaConnect/IrohaConnectCoordinator.swift` is the single switch. With it off,
the coordinator answers links, QR codes and the landing screen with the "IrohaConnect isn't
available in this version" notice before parsing anything, the Profile row is hidden, and the
account provider refuses to load key material. `IrohaConnectReleasePolicyTests` cover both
states.

## Regenerating the cross-check vectors

`fearlessTests/Common/Model/IrohaConnect/IrohaConnectWebVectors.swift` embeds JSON written by a
vitest harness that runs the web wallet's own `wire.ts`, `transactionReview.ts` and service with
the iroha-js 0.0.3 app SDK over an in-memory relay. The harness and its output are kept with the
lane's evidence (`build/reports/ios-iroha-connect-v1-20261121/vectors/` in the workspace); run it
against a checkout of the web branch with its `node_modules`.
