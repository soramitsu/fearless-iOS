# Bitcoin send in 4.2.0 (IOSUX-3)

Bitcoin send ships enabled. A remote veto (`bitcoin_send_enabled: false`, see
`remote-feature-switches.md`) can stop it; nothing remote can switch it on. This page records
what the send does in the cases that decide whether a user can lose or double-spend funds.
Every statement here is covered by a test named below.

## Recipients

The wallet's own coins are native SegWit (BIP84, `bc1q…`). It pays every standard address
type in use (`BitcoinAddressSupport`):

| Type | Mainnet | Testnet | Output size | Smallest amount |
|---|---|---|---|---|
| P2PKH (legacy) | `1…` | `m…`, `n…` | 34 vB | 546 sats |
| P2SH | `3…` | `2…` | 32 vB | 540 sats |
| P2WPKH | `bc1q…` (20-byte program) | `tb1q…` | 31 vB | 330 sats |
| P2WSH | `bc1q…` (32-byte program) | `tb1q…` | 43 vB | 330 sats |
| P2TR (Taproot) | `bc1p…` | `tb1p…` | 43 vB | 330 sats |

Bech32/bech32m checksums follow BIP173/BIP350 (mixed case, wrong checksum variant, bad
padding and wrong program lengths are invalid); base58 addresses need a valid double-SHA256
checksum. An address of the other Bitcoin network is refused. A well-formed address for a
witness version Bitcoin has not defined yet (v1 with a program that is not 32 bytes, v2–v16)
is refused as unsupported, because coins sent there could not be spent today. The fee is
computed with the real size of the recipient's output, so the quoted rate is the rate paid.
Change always returns to the wallet's own `bc1q…` address.

Tests: `BitcoinAddressSupportTests` (BIP173/BIP350 vectors, scripts, dust limits, signed
outputs), `BitcoinLocalChainE2ETests.testEveryPayableAddressType_receivesTheExactAmountAtTheQuotedFee`.

## Fee

- Esplora's `/fee-estimates` for a 2-block target, bounded to 1–1,000 sat/vB. Below 1 sat/vB
  nodes do not relay; above 1,000 sat/vB a transaction confirms in the next block even in
  the worst spikes seen so far, so a faulty or hostile estimate cannot drain the wallet.
  Anything above 10,000 sat/vB is malformed and refused. The extension uses the same bounds.
- The fee shown on the confirm screen is the fee of the exact transaction that is signed: the
  quote records the rate and the fee, and `submit` refuses to sign if the plan's fee differs
  (`feeQuoteMismatch`, "review the fee again").
- A remainder too small for a change output (below 330 sats once the change output is paid
  for) is added to the fee. It is bounded by the cost of one change output plus 330 sats.

Tests: `BitcoinFeeEstimatorTests`, `BitcoinUtxoSelectorNearMaxTests`.

## Replace-by-fee

Transactions do not signal BIP125 (`nSequence = 0xFFFFFFFF`) and the app never bumps a fee.
The 1 sat/vB floor keeps every transaction relayable. The only way the app ever replaces a
transaction is the explicit conflict described below, which spends the same coins; nodes
running full-RBF may accept it if it pays more, and otherwise refuse it, and in both cases at
most one of the two can confirm.

## Spendable balance

The portfolio shows everything the wallet owns (confirmed plus mempool). Send offers only
confirmed coins that no mempool transaction spends, because those are the only coins the
planner selects; the difference is shown on the asset screen as "Pending confirmation". "Max"
quotes the fee of sending every spendable coin to one output and sends the rest, with no
change.

Tests: `BitcoinSpendableBalanceTests`, `BitcoinSendServiceTests.testSendAllProducesNoChangeTransactionMatchingQuote`,
`BitcoinLocalChainE2ETests.testSendAll_spendsOnlyConfirmedCoinsWithoutChange`.

## A broadcast whose outcome is unknown (double-pay guard)

Before the signed transaction leaves the device it is recorded in
`BitcoinPendingBroadcastStore` (`UserDefaults`, key
`bitcoin.pending_broadcast:<walletId>:<chainId>`): txid, raw transaction, amount, fee,
recipient and inputs. It is public data once broadcast and holds no key material. If the
record cannot be written, nothing is broadcast.

Each broadcast attempt is classified:

- **not sent**: no connection was made, TLS failed, or the service answered 429 before
  forwarding. The record is removed and the user may simply try again.
- **refused**: a node answered 4xx with a reason. The wallet still looks the transaction up
  once; if no service has it, the record is removed ("This transfer wasn't sent").
- **ambiguous**: a timeout, a dropped connection, a 5xx, an unreadable reply, a different txid,
  or a refusal saying the node already has it ("txn-already-in-mempool", "already in block
  chain", "outputs already in utxo set", "same-nonwitness-data"). The wallet looks the
  transaction up (`GET /tx/:txid` on every service; `/tx/:txid/status` is never used, because
  electrs answers it with `{"confirmed":false}` for a transaction it has never seen). Found:
  success. Not found: "Transfer status is unknown", and the record stays.

While a record exists, `submit` builds and signs nothing. It first asks the indexers what
happened, using only lookups:

- the transaction (or one it replaced) is known → the record is cleared and the user is told
  the earlier transfer was sent; nothing new is sent;
- one of its coins was spent by another confirmed transaction → it can never confirm; the
  record is cleared and the new transfer proceeds;
- otherwise the user sees "An earlier transfer is unresolved" with **Retry the earlier
  transfer** (the same signed bytes again; the same txid, so it can only be the one payment),
  **Replace it with this transfer** (the new transaction must spend every coin of the
  earlier one, so the network can confirm at most one of them; its fee is quoted again
  before Confirm), and **Copy transaction ID**.

There is no time limit after which a record is forgotten: a transaction can stay in mempools
for two weeks, and forgetting it would reopen the double payment. A record that cannot be
decoded is moved aside (`bitcoin.pending_broadcast.unreadable:…`), never deleted, and does not
block the wallet. One transfer per wallet and network is in flight at a time.

Tests: `BitcoinBroadcastAmbiguityTests` (including the audit's case
`testReplyLostAfterTheNodeAcceptedIt_thenASecondConfirmNeverSpendsOtherCoins`),
`SendDependencyErrorSurfacingTests.testBitcoinUnknownOutcomeSheetOffersCopyAndSameHexRetry`
and the other Bitcoin sheet tests, and on regtest
`testAmbiguousBroadcast_whenTheNodeTookItAndTheReplyWasLost_thenNoSecondPaymentIsEverBuilt`,
`testAmbiguousBroadcast_whenNothingReachedTheNode_thenRetrySendsTheSameTransactionOnce`,
`testReplacement_whenTheEarlierTransferNeverLeft_thenOnlyOneOfTheTwoCanConfirm`.

## Endpoints, failover and rate limits

Mainnet uses `https://mempool.space/api`, then `https://blockstream.info/api`; testnet the
same services' `/testnet/api`. `BitcoinFailoverIndexerClient`:

- reads go to the first service not backing off; on 429/503 (honouring `Retry-After`, capped
  at 15 minutes), 408 or 5xx the service backs off for 30 s, doubling to 15 minutes, and the
  next service answers. Being offline does not count against a service. A request the
  service refused (bad address, 4xx) is not repeated elsewhere;
- a broadcast is offered to each service in turn until one accepts it (always the same bytes);
- a lookup asks every service: seen if any has it, unseen only if at least one answered.

A wallet scan that is rate limited also backs off (2 minutes doubling to 15) and the
portfolio keeps the last known balance, marked as possibly outdated.

Tests: `BitcoinBroadcastAmbiguityTests.testFailoverClient_*`, `testTransport_*`,
`BitcoinBalanceSyncTests`, and on regtest
`testRateLimitedPrimary_thenTheTransferCompletesThroughTheFallback`.

## Before the staged rollout

A small funded mainnet canary per platform remains a team task in the release checklist; no
automated test sends on mainnet or a public testnet.
