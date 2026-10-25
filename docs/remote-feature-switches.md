# Remote feature switches (4.2.0)

The app reads `appConfigs/feature_toggle` from `shared-features-utils`
(`ApplicationConfig.featureToggleURL`) through `FeatureToggleProvider` and applies it in
`MultiChainFeaturePolicy` (`fearless/ApplicationLayer/Services/FeatureToggle/FeatureToggleConfig.swift`).
For fund-moving features the remote file is **veto-only**: it can turn a shipped feature off,
and it can never turn on anything this build compiles off or keeps behind signed authority.

## Semantics

| Key | Shipped default | Remote `false` | Remote `true` | Key absent / fetch fails |
|---|---|---|---|---|
| `polkaswap_mutations_enabled` (swap, liquidity) | on | off, remembered | clears a remembered veto | keeps the remembered state |
| `bitcoin_send_enabled` | on (`UniversalSendReleasePolicy.production`) | off, remembered | clears a remembered veto | keeps the remembered state |
| `solana_send_enabled` | on (`UniversalSendReleasePolicy.production`) | off, remembered | clears a remembered veto | keeps the remembered state |
| `demeter_mutations_enabled`, `polkamarkt_mutations_enabled`, `cross_chain_mutations_enabled` | off | stays off | needs signed `mutation_authorization` as before | off |

- A veto is stored (`RemoteKillSwitchStore`, `UserDefaults` keys
  `feature.kill_switch.polkaswap_mutations`, `feature.kill_switch.bitcoin_send`,
  `feature.kill_switch.solana_send`) only from a successfully decoded payload that states the
  key as `false`. It survives restarts, offline launches, failed or undecodable fetches and
  later payloads that omit the key. Only an explicit `true` clears it. These keys hold policy
  flags only, never wallet or key material, and no released version wrote them before 4.2.0,
  so an upgrade starts with every shipped feature on.
- Values must be JSON booleans. A string such as `"false"` makes `GithubJSONDecoder` reject the
  whole document, which takes the failed-fetch path: remembered vetoes stay, nothing is enabled.
- Bitcoin and Solana sends are gated twice: `SendDepencyContainer.prepareDepencies` refuses a
  vetoed network before account lookup, the dependency cache or any transport is touched
  (`UniversalWalletSendRoutingError.bitcoinSendPaused` / `.solanaSendPaused`), and
  `BitcoinTransferService.submit` / `SolanaTransferService.submit` re-check the gate before key
  access, signing or broadcast (`TransferServiceError.bitcoinSendPaused` / `.solanaSendPaused`),
  so a veto that arrives while the confirm screen is open still sends nothing.
- Universal-wallet TON send and Iroha (Taira / SORA Nexus) send stay compiled off
  (`TonProductionSendReleasePolicy`, the Iroha routing guard); the remote file cannot change them.

## What users see

- No paused copy appears for Bitcoin or Solana unless a veto is active.
- Under a veto, Send explains the pause ("Bitcoin sending is paused right now"), says what
  still works (balances unaffected, receiving works) and offers **Receive** for the same
  network or **Close**. The confirm screen shows the same sheet if the veto lands after review.
- Every other routing refusal is explained too instead of leaving Send without a fee:
  universal TON, Iroha, unsupported assets, a missing account, and connection failures
  (with **Retry**). See `SendUnavailableReason` in `fearless/Modules/Send/SendFlow.swift`.

## Payloads

Production payload for 4.2.0 (no change needed; every shipped feature stays on):

```json
{ "pendulum_case_enabled": false, "nft_enabled": false, "dapp_enabled": false }
```

Emergency veto template (publish only the keys you need to turn off; never preemptively):

```json
{ "pendulum_case_enabled": false, "nft_enabled": false, "dapp_enabled": false,
  "bitcoin_send_enabled": false, "solana_send_enabled": false,
  "polkaswap_mutations_enabled": false }
```

To lift a veto, publish the same key with `true` and keep it published; removing the key keeps
the veto on devices that already saw it. Android shares this file and these keys (its
`docs/remote-feature-switches.md`), and the extension uses `web_config.json` `actions.*`. The
cross-platform template and its checker live in the workspace root:
`config/remote-config/feature-toggle.veto-only.prepared.json` and
`scripts/remote-config-veto-template.mjs`. Nothing in this release publishes remote config.

## Tests

`FeatureToggleKillSwitchDecodingTests`, `UniversalSendReleasePolicyTests`,
`SendDependencyGateTests`, `SendDependencyErrorSurfacingTests` and `FeatureToggleProviderTests`
in the `fearless.tests` scheme. `SendLocalChainE2ETests` proves the same gate with the real send
code on local `bitcoind -regtest` and `solana-test-validator` chains
(`docs/local-chain-send-tests.md`).
