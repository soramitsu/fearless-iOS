# Released TON functionality restoration goals

Status: implementation acceptance goals complete. Combined qualification covers 526 unique iOS tests and 41 SDK tests. Final swap-history/link tests pass 55/55; persisted session cosmetics and origin/key controls pass 24/24. No live transaction has been submitted.

## Proven source compatibility

Release tag `4.1.0` had `TonConnectServiceImpl`, `TonConnectEventsCenter`, `TonConnectSessionCrypto`, the `TonWebBridge` module, and TonConnect routing in its WalletConnect coordinator. Before this audit, the current checkout retained `CDTonConnectedApp` and `CDTonDapp` data in the compatibility store but removed those runtime services and reported TonConnect unsupported. Both runtime entry points and the Profile action are now restored.

The stored session fields are `walletId`, `clientId`, `appUrl`, `name`, `iconUrl`, `publicKey`, `privateKey`, `connectionType`, and `identifier`. `CDChain.tonBridgeUrl` is also retained. Existing HTTP sessions depend on the original NaCl session key and configured bridge, not a newly generated session. The current pinned TonSwift package includes TweetNacl transitively; the current TonAPI package no longer includes the old `TonConnectAPI` generated client.

The release-pinned SSFModels commit `b3e2bf1` represents regular Substrate/EVM wallets and native TON wallets separately. Regular wallets have a Substrate identity; native TON wallets have their exact JSON-encoded TonSwift address and signing identity. Native TON signing credentials must use `LegacyTonAccount.signingCredentials(keystore:metaId:)` so restored sessions cannot sign as a different selected wallet.

## Implementation acceptance goals

- [x] Restore session inventory from existing Core Data rows and preserve unknown/malformed entries without wiping them. Validate NaCl public/private key binding and original wallet ownership; never regenerate an existing session key.
- [x] Restore HTTP bridge transport using the retained bridge configuration, encrypted messages, bounded parsing and cancellable background startup. A bridge/network error must affect only that session and permit retry while wallets remain usable.
- [x] Restore the released connect/deep-link and JS-bridge entry points, manifest display, explicit user approval and PIN/biometric authorization. Bind JS messages to the displayed main-frame origin and connected application.
- [x] Restore proof replies and transaction requests for the original account. Validate network/from/expiry, at most four messages, payload/state-init limits and exact request identity before confirmation. Reuse validated TON credentials and preserve the existing fee-quote, pending-intent and uncertain-broadcast recovery guarantees.
- [x] Restore session selection/disconnection from Profile, recognizing `wallet.legacyTonAccount` even without a universal chain account.
- [x] Verify persisted HTTP/JS session reload, native signing/proof fixtures, reconnect with unchanged session keys, request rejection/authorization, wallet switching/deletion, offline retry and no duplicate broadcasts using synthetic data and fake transports.

Verified Jetton transfer restoration extends the existing typed TON intent/quote/journal instead of relaxing native execution checks globally. Real Jetton transfers have child traces, so its execution policy must validate their bounded successful effects separately.

## Protocol references checked

- [TON Connect HTTP and JS bridge specification](https://github.com/ton-blockchain/ton-connect/blob/main/spec/bridge.md)
- [TON Connect session encryption specification](https://github.com/ton-blockchain/ton-connect/blob/main/spec/session.md)
- [TON Connect protocol reference](https://docs.ton.org/applications/ton-connect/api-reference/protocol)

Source restoration must preserve released behavior while applying the current protocol limits relevant to that behavior. This completed implementation checklist is supported by `legacy-full-tonconnect-verified.xcresult` (516/516) and the separate TonSwift SDK run (41/41). It does not replace distribution-signed in-place upgrade acceptance. Exact evidence and the final compatibility follow-up are recorded in `legacy-upgrade-audit-20260906.md`.
