# WalletConnect in Fearless for iOS

Fearless speaks WalletConnect v2 with its own client, `Packages/FearlessWalletConnect`. It replaced Reown's
`reown-swift` 1.8.0 (`WalletConnectSign`, `ReownWalletKit` and the rest), which is under the WalletConnect Community
License and is not open source, together with what came with it: Reown's prebuilt `yttrium` Rust binaries,
`WalletConnect/QRCode`, `swift-qrcode-generator`, `SwiftImageReadWrite` and Coinbase's `wallet-mobile-sdk`. The client
uses only Apple's system frameworks (Foundation, CryptoKit, Security, Combine), so it adds no package.

The app plays the wallet role: dApps pair with Fearless by its pairing link, propose sessions, and send requests. The
client does exactly that. A session in which Fearless is the controller is a wallet session; the client refuses
requests in any other, and namespace updates or extensions from the dApp.

## Pairing and signing in the app

- **Pairing.** A `wc:` QR code from the scanner or the gallery, a `wc:` link, or `fearless://wc?uri=<wc: URI>`
  (`WalletConnectURLHandler`). A link that opens the app waits until WalletConnect starts after the unlock; a link that
  cannot pair gets a notice. A `wc:` link without a key only brings the wallet forward.
- **What is signed.** EVM `personal_sign`, `eth_signTypedData` and `eth_signTypedData_v4` (the legacy array form is
  declined), `eth_signTransaction` and `eth_sendTransaction`, and Polkadot `polkadot_signMessage` and
  `polkadot_signTransaction`. Before the confirmation opens, the request is
  bound to an account the session approved, checked against its network, and decoded: an EVM transaction is quoted
  by the wallet, a Substrate call must encode back to the dApp's bytes for the chain's runtime, and messages are
  signed inside polkadot-js's `<Bytes>` envelope.
- **Confirmation.** It shows the network, the recipient, the amount and the fee (for messages, the text), the wallet
  and account, the app, and the site the request came from as WalletConnect Verify reports it: on a domain mismatch
  the site Verify saw, and "Domain not verified" with a warning when Verify could not check it. Apps Verify flags as
  scams are declined before anything opens.
- **The PIN.** Sign asks for the PIN or trusted biometrics through `SubmissionAuthorizer`, as every fund-moving and
  staking submission does; without a PIN nothing is signed.
- **Remote vetoes.** `evm_dapp_signing_enabled` and `polkadot_dapp_signing_enabled` in the remote feature toggles can
  pause signing per network (`ton_dapp_signing_enabled` does the same for TON Connect). An absent key keeps signing
  on; only an explicit `false` pauses it, and the pause is remembered until an explicit `true`. A paused request is
  declined and the user is told nothing was signed; the confirmation checks again before and after the PIN.

## Files

| File | What it does |
| --- | --- |
| `Crypto/WalletConnectCrypto.swift` | X25519 key agreement, HKDF-SHA256 session keys, SHA-256 topics, ChaCha20-Poly1305 envelopes (type 0; type 1 is read, never opened) |
| `Crypto/RelayAuth.swift` | The relay's sign-in: an EdDSA JWT, valid for 24 hours, issued by the client's Ed25519 identity as a did:key |
| `Relay/RelayConnection.swift`, `Relay/RelayTransport.swift` | The relay over `URLSessionWebSocketTask`: subscribe, batch subscribe, publish, the batch message fetch, acknowledging each delivery, keep-alive pings, reconnecting with back-off |
| `Sign/WalletConnectClient*.swift` | Pairing, proposals, approval and refusal, settlement, requests and answers, ping, disconnection, expiry |
| `Sign/SignProtocol.swift` | Each method's relay tag and lifetime, and the protocol's error codes |
| `Sign/PeerMessageReader.swift` | Reads what dApps send; anything malformed or oversized is refused |
| `Verify/VerifyClient.swift` | The Verify service: the dApp's origin from a signed ES256 attestation, or the service's answer by message hash |
| `Storage/*.swift`, `Migration/LegacyWalletConnectImporter.swift` | The client's record and keys, and the import of what the earlier SDKs saved |
| `JSON/*.swift`, `JSONRPC/JSONRPC.swift` | A strict JSON reader that keeps numbers exact, and JSON-RPC messages |
| `Model/*.swift`, `Pairing/WalletConnectURI.swift` | Sessions, proposals, requests, CAIP-2/CAIP-10 ids, namespaces, pairing links |

## On the wire

The client follows the published protocol and the WalletConnect SDK most dApps ship:

- Relay methods `irn_subscribe`, `irn_batchSubscribe`, `irn_unsubscribe`, `irn_publish`, `irn_batchFetchMessages`, and
  `irn_subscription`, which it acknowledges before handling, because the relay redelivers what is not acknowledged.
- The relay URL carries `auth` (the JWT, its audience the relay URL), `projectId`, `ua` and `bundleId`; the relay
  checks `bundleId` against the project's allowed iOS apps, as it did for Reown.
- Envelopes are padded base64 of `0x00 | nonce(12) | ciphertext | tag(16)`; the padding may be missing on the way in.
- Relay tags and lifetimes (seconds): proposal 1100/1101 and refusal 1120, 300; settlement 1102/1103, 300; update
  1104/1105 and extend 1106/1107, 86400; request 1108/1109, 900; event 1110/1111, 300; delete 1112/1113 and ping
  1114/1115, 86400; pairing delete 1000/1001, 86400; pairing ping 1002/1003, 30; an unknown `wc_` method 0, 86400.

The relay holds a message published to a topic nobody else listens to, and gives it to the first client that
subscribes. That is how a proposal published before the wallet scans the link still reaches it. Each held message is
delivered once; the client handles each message once, however often it arrives (by the SHA-256 of the envelope, and
by request id).

The relay connection closes when the app goes to the background. On return the client reconnects with a new sign-in
token and fetches what the relay held meanwhile; a request a dApp sent while Fearless was in the background arrives
then.

Not offered: one-click authentication (`wc_sessionAuthenticate`; dApps fall back to their proposal), link mode, push
notifications, and the dApp role.

## Storage and upgrades

The client keeps one record, `jp.co.soramitsu.fearless.walletconnect.state.v1`, in the WalletConnect app group's user
defaults (sessions, pairings, pending proposals and requests; no keys), and one keychain item, service
`jp.co.soramitsu.fearless.walletconnect`, account `secrets.v1`, in the app group's access group, readable after the
first unlock and never leaving the device (the relay identity and each topic's key). Keys are written before the
record that names them; a session whose key is missing is dropped on start.

On start the client carries over what the earlier SDKs saved and it does not know yet:

- Fearless 3.0.5 - 4.1.0 ran WalletConnectSwiftV2: records in the standard user defaults
  (`com.walletconnect.sdk.sessionSequences.<topic>`, `com.walletconnect.sdk.pairingSequences.<topic>`,
  `com.walletconnect.iridium.client_id.public`) and keys as generic passwords, service `com.walletconnect.sdk`, in the
  app's default keychain access group.
- Fearless 4.2.0 and 4.2.1 up to build 2026.11.6 ran Reown 1.8.0, which moved the same records into the app group's
  user defaults and keychain access group.

Build 2026.11.7 of 4.2.1 had no WalletConnect and deleted those records once per install
(`RetiredWalletConnectDataCleanup`). That clean-up is gone again; on a device that ran 2026.11.7 there is nothing left
to carry over, and its dApps pair again.

It imports live wallet sessions whose key is there and matches the topic (the SHA-256 of the key), live pairings whose
key is there (a pairing's topic is chosen at random by some SDKs, so it is not checked against the key), and the relay
identity, so the relay treats the new client as the one that subscribed. It leaves the earlier records in place,
so an earlier build still finds them, and it removes an imported session's records and keys when the session ends, so
a downgrade cannot bring an ended session back. Expired sessions are not imported; the Connections screen's reconnect
record (`WalletConnectLegacyStorageMigrator`) still lists sessions from before the app group that did not carry over.
Proposals and requests in flight are not imported.

## Validation

- `swift test` in `Packages/FearlessWalletConnect` runs the package's tests on macOS: the cryptography against RFC 7748
  and WalletConnect relay-auth vectors, the JSON reader, pairing links, namespaces, Verify, the whole wallet role
  against an in-memory relay that follows the live relay's delivery rules, and the import of both earlier layouts.
- `fearlessTests/ApplicationLayer/WalletConnect/WalletConnectLegacyStorageContinuityTests.swift` runs the real
  `WalletConnectServiceImpl.setup()` in the app over the exact records those releases wrote, in the real app group and
  keychain.
- Two checks use the WalletConnect SDK most dApps ship, installed outside this repository (it is never a dependency):
  - `scripts/walletconnect/reference-vectors.mjs` writes cryptography vectors computed by `@walletconnect/utils`;
    `ReferenceVectorTests` compares keys, topics, message hashes, byte-identical envelopes, did:key identities and JWT
    headers and claims with them.
  - `scripts/walletconnect/reference-dapp.mjs` runs `@walletconnect/sign-client` as a dApp on the live relay, and
    `LiveRelayInteropTests` runs the wallet against it: approval, an answered and a refused request, pings both ways,
    the wallet's disconnection, and a refused second proposal.
  - `scripts/walletconnect/reference-dapp-sign.mjs` asks for real `personal_sign`, `eth_signTypedData_v4` and
    `polkadot_signMessage` signatures and checks them with `ox` and `@noble/curves`; `WalletConnectLiveSigningTests`
    (`FEARLESS_WC_SIGN_LIVE=1`) answers with the app's own preparation and signer.

```bash
cd Packages/FearlessWalletConnect && swift test
```

```bash
WALLETCONNECT_REFERENCE_SDK=<dir> node scripts/walletconnect/reference-vectors.mjs /tmp/wc-vectors.json 400
```

```bash
cd Packages/FearlessWalletConnect && FEARLESS_WC_VECTORS=/tmp/wc-vectors.json swift test --filter ReferenceVectorTests
```

For the live check, start the dApp first and then the wallet test with the same exchange directory and project id:

```bash
WALLETCONNECT_REFERENCE_SDK=<dir> WALLETCONNECT_PROJECT_ID=<id> FEARLESS_WC_EXCHANGE=<empty dir> node scripts/walletconnect/reference-dapp.mjs
```

```bash
cd Packages/FearlessWalletConnect && FEARLESS_WC_LIVE=1 WALLETCONNECT_PROJECT_ID=<id> FEARLESS_WC_EXCHANGE=<same dir> swift test --filter LiveRelayInteropTests
```

`WALLETCONNECT_RELAY_URL` picks the relay for both sides (default `wss://relay.walletconnect.com`; the app uses
`wss://relay.walletconnect.org`).

The upgrade check runs the real earlier SDK. `scripts/walletconnect/reference-dapp-upgrade.mjs` pairs a dApp with a
Reown 1.8.0 build (4.2.1 build 2026.11.6, `f56e51828`) on a fresh simulator, keeps its session, and sends a request
while no wallet runs. Then the current build is installed over the same app data and
`WalletConnectReownUpgradeLiveTests` (skipped unless `FEARLESS_WC_UPGRADE_LIVE=1`; it reads `FEARLESS_WC_EXCHANGE` and
`WALLETCONNECT_PROJECT_ID` through `TEST_RUNNER_` variables) checks that the session carried over with the relay
identity, that the held request arrives and is declined, that pings work both ways, and that ending the session
removes Reown's record of it. The Reown side needs a scratch test in a checkout of that build that pairs, approves and
flushes the defaults before the test runner ends the app; the project id reaches that build as
`FL_WALLET_CONNECT_PROJECT_ID` in `fearless/env-vars.sh`.
