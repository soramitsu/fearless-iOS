# Local-chain send tests

`SendLocalChainE2ETests`, `BitcoinLocalChainE2ETests` and `SolanaLocalChainE2ETests` (all in
`fearlessTests/Modules/WalletSend/SendDependencyGateTests.swift`) drive the app's real Bitcoin
and Solana transfer services against private local chains. The chains hold no value, and every
request is confined to `127.0.0.1`: the Bitcoin indexer transport refuses any URL other than
the two testnet Esplora bases it rewrites (mempool.space and blockstream.info, each onto its
own simulated service on the shim), and every Solana RPC URL must be a loopback `http` address.
Nothing here can broadcast to mainnet or testnet.

## Run

```sh
scripts/test-local-chain-sends.sh <work-dir> \
  -workspace fearless.xcworkspace -scheme fearless.tests -configuration Debug \
  -destination 'platform=iOS Simulator,id=<udid>' -derivedDataPath build/DerivedData \
  test-without-building
```

Build first (`build-for-testing`). `FEARLESS_LOCAL_CHAINS` names the chains to start
(`bitcoin solana` by default); `FEARLESS_LOCAL_CHAINS=solana` starts only the Solana validator
and its proxy and runs `SolanaLocalChainE2ETests` (set `FEARLESS_LOCAL_CHAIN_SUITES` to add the
two Solana tests of `SendLocalChainE2ETests`). With `test-without-building`, passing
`-xctestrun <DerivedData>/Build/Products/fearless.tests_iphonesimulator<version>-arm64.xctestrun`
instead of `-workspace`/`-scheme` skips package resolution. The runner starts, on free
loopback ports under `<work-dir>`:

- `bitcoind -regtest` (`/opt/homebrew/bin/bitcoind`, Bitcoin Core 31.1) with a mature miner
  wallet, behind `scripts/local-chains/esplora_regtest_shim.py`, a small Esplora-compatible
  HTTP server for the endpoints the wallet calls (address stats, UTXOs, fee estimates,
  broadcast, transaction, status, outspend) plus `/regtest/fund`, `/regtest/mine` and
  `/regtest/mempool` for the tests. It answers like electrs where safety depends on it
  (`/tx/:txid` is 404 for an unknown transaction, `/tx/:txid/status` is
  `{"confirmed":false}`), serves `/svc/<name>/...` as separate services over the one node,
  and has test controls: `/regtest/faults` (429/5xx, dropped connections, a broadcast the node
  accepts whose reply is lost), `/regtest/requests` (what each service was asked),
  `/regtest/reset` and `/regtest/address` (node-wallet addresses of every type);
- `solana-test-validator` (`/opt/homebrew/bin`, Agave 4.3), funded through its faucet with
  `requestAirdrop`, started with an SPL token written by
  `scripts/local-chains/solana_spl_fixture.py`: a mint and a token account (1,000 tokens, 6
  decimals) held by `HAgk14…`, the Solana address of the BIP39 test phrase "abandon … about",
  loaded as genesis accounts in the SPL Token program's own layout;
- `scripts/local-chains/solana_rpc_proxy.py` in front of the validator, serving it as two RPC
  nodes (`/svc/a-primary`, `/svc/b-secondary`) with test controls: `/proxy/faults` (HTTP
  403/429/5xx, publicnode's "Request blocked", a dropped connection before forwarding, and a
  forwarded transaction whose reply is lost or turned into a 502), `/proxy/requests` and
  `/proxy/reset`.

It passes the endpoints as `TEST_RUNNER_FEARLESS_E2E_ESPLORA_URL`,
`TEST_RUNNER_FEARLESS_E2E_SOLANA_RPC_URL`, `TEST_RUNNER_FEARLESS_E2E_SOLANA_PROXY_URL`,
`TEST_RUNNER_FEARLESS_E2E_SOLANA_SPL_MINT` and `TEST_RUNNER_FEARLESS_E2E_SOLANA_SPL_SOURCE`, runs
only the local-chain suites, and stops every process on exit. Without those variables the suite skips, so the regular test run never needs
local chains.

The wallet's Bitcoin code knows mainnet and testnet. Regtest shares testnet's BIP84 coin type
and differs only in the bech32 prefix, so the tests use the Bitcoin testnet chain and the shim
maps `tb1...` addresses onto regtest `bcrt1...` scripts. The signed bytes are identical.

## What is asserted

- Bitcoin, sending enabled by default: the transfer reaches the mempool, confirms, spends the
  funded UTXO, pays the recipient the exact amount, returns the exact change to the wallet's
  own address and pays exactly the quoted fee.
- Bitcoin, a remote veto delivered through the real feature_toggle decoding after the fee
  quote: `submit` throws `bitcoinSendPaused`, the mempool is unchanged and the UTXO is unspent.
- Bitcoin double-pay guard (`BitcoinLocalChainE2ETests`): the node takes a transaction but
  the reply is lost and lookups fail → "status unknown", exactly one transaction in the
  mempool, a second Confirm is refused before anything is planned or signed, the other coin
  stays unspent, and once lookups work the wallet reports the first transfer as sent. A
  broadcast that never reached the node → "status unknown" (not the false "sent" that
  `/tx/:txid/status` would give), and Retry sends the same bytes once. A replacement spends
  the unresolved transfer's coin, so the node refuses the earlier transaction and only the
  replacement confirms.
- Bitcoin failover: with mempool.space answering 429, reads and the broadcast go to
  blockstream.info and mempool.space gets no further reads during its Retry-After.
- Bitcoin recipients: P2PKH, P2SH, P2WPKH, P2WSH and Taproot each receive the exact amount at
  the quoted fee, with change on the wallet's own address.
- Bitcoin "Max" with an unconfirmed incoming payment: the total counts it, the spendable
  balance does not, and the transfer spends only the confirmed coin with no change.
- Solana, sending enabled by default: the transfer confirms; the recipient gains the exact
  lamports and the sender pays the amount plus exactly the quoted fee.
- Solana, vetoed: `submit` throws `solanaSendPaused`; no new signature for the sender and an
  unchanged balance.
- Solana priority fee (`SolanaLocalChainE2ETests`): the validator charges exactly the quoted
  5,002 lamports (base fee plus the ComputeBudget priority fee), and the app's own JSON-RPC
  balance reader shows the new balance.
- Solana rent: amounts below the validator's own rent-exempt minimum for a new account, and
  transfers that would leave the sender between zero and that minimum, are refused before
  signing; "Max" empties the account and is accepted.
- SPL token: the first transfer to a wallet without a token account opens it and charges the
  quoted network fee, priority fee and the account's rent exactly; the second pays no rent; the
  token amounts move exactly. Sending tokens to a token account, or SOL to a token account, is
  refused with no new signature.
- Lost reply: one node forwards the transaction and the reply is lost, the other answers 502;
  the signature status settles it as sent, with one payment.
- Unreachable broadcast: no node takes it; "status unknown", a second Confirm signs and sends
  nothing, and Retry sends the same transaction, which lands once. Waiting instead until the
  blockhash expires (about 150 s on the test validator): both proxy nodes are one host,
  127.0.0.1, and one host cannot prove that nothing left the wallet, so the next Confirm is
  stopped once with "Your earlier transfer could not be verified" and the record is released;
  confirming again sends the next transfer, and only it is paid.
- Failover: with the first node rate limiting everything, one request finds out and reads and
  the broadcast go to the second node; with the first node blocking token lookups, token
  balances come from the second.
- Token lookups refused by every node (as publicnode refuses them): the portfolio read still
  returns the validator's SOL balance and reports the token accounts as unread, a send's
  strict read fails, and the token comes back once a node answers.
- The app's Send and Confirm screens
  (`testSendAndConfirmScreens_pastedRecipientAndTypedAmount_payOnceOnTheValidator`): the real
  view controllers, presenters and interactors, shown in a window. The recipient is pasted into
  the address field and the amount typed into the amount field through the text-field calls
  UIKit makes, Continue opens Confirm, which shows the quoted network fee (as the app rounds
  it) and the amount, and Confirm sends to the validator: the recipient gains the typed amount,
  the sender pays it plus the quoted fee, and the sender has exactly one new signature. Only
  what leaves the device is replaced: balances come from the validator, and the address score
  and scam lookups answer nothing. The test runs in the unit-test host, not as an XCUITest: the
  project has no UI-test target, and the full app contacts public networks at launch and binds
  Solana to mainnet's genesis hash.

Every Solana transfer in these tests uses the app's own RPC client and failover, balance
reader, recipient checks, builder, signer, simulation, pending-broadcast record and broadcast.
