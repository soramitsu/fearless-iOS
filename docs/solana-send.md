# Solana send in 4.2.0 (IOSUX-4)

Solana ships as an app-owned network with send enabled, like Bitcoin. A remote veto
(`solana_send_enabled: false`, see `remote-feature-switches.md`) can stop it; nothing remote
can switch it on. This page records what the wallet does in the cases that decide whether a
user can lose funds or pay twice. Every statement here is covered by a test named below.

## The network and the account

The shared chain registry does not publish Solana, so the wallet merges its own mainnet row
(`UniversalWalletRegistry.solanaMainnetChainModel`: chain id `solana:mainnet`, SOL with 9
decimals, priced by the CoinGecko id `solana`) into the downloaded registry at runtime, as it
does for Bitcoin. Solana is a universal-wallet network, so the chain registry never opens a
Substrate connection to it.

A mnemonic wallet gets the Solana account its phrase derives at `m/44'/501'/0'/0'`, the
address Phantom, the extension and Android show for the same phrase. On the first launch of
4.2.0, `ServiceCoordinator` adds it to wallets that do not have one, together with the other
app-owned networks (`UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts`). Only
the public key is written; no secret is created, changed or copied, and signing uses the
wallet's existing root phrase. A Solana account the wallet already has (one carried over from
another device, possibly from another phrase) is kept as it is and is never a conflict: no
earlier iOS release created a Solana account, so there is nothing to compare it with and
replacing it could hide funds. A malformed row is kept too; the derived account sits beside
it and is the one shown. Raw-seed and JSON wallets have no phrase to derive from and are
offered the existing "Wallet phrase required" flow.

Tests: `UniversalWalletAccountAddressResolverTests.testUpgradeFrom404MnemonicWallet_addsTheSolanaAccountThePhraseDerivesAndNothingElse`
(the keystore exactly as App Store 4.0.4 wrote it), `testExistingSolanaAccountIsNeverReplacedOrTreatedAsAConflict`,
`testMalformedSolanaRowStaysAndTheDerivedAccountIsTheOneShown`,
`testSolanaProductionChainIsAnAppOwnedMainnetOnJSONRPC`, `ChainAssetListTests.testStoredSeedAdoptionMergesAccountsIntoNewerWalletPayload`,
`UniversalWalletV2VectorsTests` (derivation vectors).

## Endpoints and failover

Nothing on mainnet depends on the SORA Solana indexer `si.soramitsu.io`, which serves Solana
testnet and has no `/service-info`. Balances, rent, fees, blockhashes, simulation, broadcast
and signature lookups all use Solana JSON-RPC through `SolanaFailoverRpcClient`, in this
order (`SolanaRpcEndpoints`):

1. the build's own provider, if CI sets `FL_SOLANA_RPC_URL` (generated into
   `SolanaRpcCIKeys.providerURL`). It is optional. It must be an `https` URL with a host
   that carries any key in its path, because the client drops query strings; scheme and host
   are case-insensitive and a fragment is dropped. Unset or empty means no provider, and the
   public nodes serve alone. A value the app would ignore (`http`, quotes, a query string,
   credentials, no host, not a URL) stops `scripts/ci/generate-ios-service-configuration.py`,
   and with it the build, with a message naming the variable but not its value, so a typo
   cannot silently leave a build on the public nodes. It is used for mainnet only;
2. a node the user selected for the network, if any;
3. the public nodes `https://api.mainnet-beta.solana.com`,
   `https://solana-rpc.publicnode.com` and `https://public.rpc.solanavibestation.com`.

Every node the wallet asks learns the wallet's address, because balance and token-account
reads name it; that includes public.rpc.solanavibestation.com, which is asked for token
accounts whenever the two nodes before it refuse them.

A provider URL carries its key, and `URLError` keeps the URL it failed on, so Send, Confirm,
the asset screen and `Logger.customError` log errors through `Error.logSafeDescription`, which
reduces a `URLError` to its code and replaces every other URL.

Checked on 2026-10-11 with read-only calls: both public nodes answer `getHealth`, balances,
rent, priority fees, account info and block height; publicnode refuses
`getTokenAccountsByOwner` ("Request blocked", HTTP 403), so token balances come from
api.mainnet-beta.solana.com unless a provider is configured. solana.drpc.org (free plan),
rpc.ankr.com (key required), mainnet.rpcpool.com (403) and OnFinality (rate limited without a
key) are not usable without an account and are not listed.

Checked on 2026-10-24: publicnode still refuses `getTokenAccountsByOwner` and mainnet-beta
rate limits it, so on the public nodes token balances did not load.
public.rpc.solanavibestation.com (mainnet genesis `5eykt…`, no key, any origin) serves it for
SPL Token and Token-2022, but answers only about two requests a second per address:
back-to-back calls get HTTP 429 with an HTML page, calls 600 ms apart all pass. The wallet
therefore keeps 650 ms between its requests to that node (`SolanaRpcEndpoints.requestSpacing`,
shared by every client in the app and counting the cluster check that precedes each request),
reads the two token programs one after the other, and after a 429 from it waits 1 s and asks
it once more before the read fails. A token read through it takes about 2.6 s.
**Release recommendation:** set `FL_SOLANA_RPC_URL` to a keyed mainnet provider for the
release build; without it token balances depend on one free public node and its rate limit.

The failover client:

- sends reads to the first node that is not backing off. HTTP 401/403/429/5xx and JSON-RPC
  server errors (-32000 and below, which includes publicnode's "Request blocked") back the
  node off for 30 s, doubling to 15 minutes, and the next node answers. Being offline does not
  count against a node. A request the wallet itself rejected (malformed address) is not
  repeated. When every node is backing off they are all asked anyway. A 429 is the node
  asking for a pause whatever its body (often an HTML page), never a bad answer; a node with a
  request spacing that answered 429 is asked once more after a 1 s pause;
- offers a signed transaction to each node in turn until one accepts it, always the same
  bytes, so a second node can only accept or refuse the same payment. A node that judged the
  transaction (below) ends the broadcast while no node may have relayed it; after a node that
  may have relayed it, the rest get the same bytes with preflight skipped;
- asks every node for signature statuses: a signature counts as seen as soon as one node has
  it and as unseen only when at least one node answered;
- treats a transaction as expired on a node only when that node has finalized past its last
  valid block height and still has no trace of it, and reports every distinct host that proved
  it (lowercased, without a trailing dot, port or path, so two spellings or two paths of one
  host count once). A node that still accepts the blockhash vetoes the others; a landed status
  anywhere wins.

Tests: `SolanaRpcClientTests` (`testFailover*`, `testBroadcast*`,
`testSignatureStatusesTakeTheMostConfirmedAnswerOfAnyNode`,
`testResolveSignatureNeedsANodeThatProvesExpiryAndAnySightingWins`,
`testResolveSignature_countsEachHostThatProvesExpiryOnce`,
`testMainnetNodesAreTheProviderThenPublicJSONRPCNeverTheIndexer`,
`testOptionalProvider_whenAbsentOrUnusable_thenThePublicNodesServeAlone`,
`testUserSelectedNodeIsAskedFirst`,
`testTokenAccounts_whenThePublicNodesRefuseThem_thenTheyComeFromSolanaVibeStation`,
`testTokenAccounts_whenSolanaVibeStationAnswers429WithAnHTMLPage_thenBothProgramsStillLoad`,
`testSol_whenEveryTokenReadIsRefused_thenSolIsStillReadAtOnce`,
`testPacer_spacesRequestsToARateLimitedNodeOnly`), `SolanaRpcBalanceSyncTests`,
`AccountInfoRemoteServiceTests.testFetchAccountInfosMapsSolanaNativeAndTokenBalancesWithoutSubstrateStorage`,
and on the local validator `testRateLimitingFirstNode_thenReadsAndTheBroadcastUseTheSecond`,
`testNodeThatBlocksTokenLookups_thenBalancesComeFromTheNextNode`.

## Balances

`SolanaRpcBalanceSync` reads `getBalance` and `getTokenAccountsByOwner` for the SPL Token and
Token-2022 programs. Wrapped SOL is not counted twice and an account another owner holds is
not this wallet's balance. A failed SOL read throws, so the portfolio keeps the last known
balance (`RemoteLastKnownBalanceStore`) and never shows zero for an outage. SOL does not wait
on the token accounts: when no node serves `getTokenAccountsByOwner` (publicnode refuses it),
the portfolio read (`portfolioBalances`) still returns the new SOL balance and says the token
accounts were not read (`tokenBalancesUnavailable`). A partial list (one token program read,
the other not) is not used. What each screen does with that:

- The wallet overview writes only the new SOL balance to the balances last known and fails
  the network's scan. It then shows the fresh SOL and every token balance it last knew (never
  zero, never written over), the network shows "Balance update failed", and its staleness
  keeps counting from the last complete scan.
- Send and Confirm read the one balance they may spend. For SOL only the SOL read must
  succeed. For a token the token accounts must be read now; if no node returns them the read
  fails: Send shows no amount for the token, neither an older one nor zero, and Max offers
  nothing; Confirm keeps its button loading. Transfers read the token accounts strictly as
  well and stop if they cannot. The asset screen reads the same way and shows the overview's
  balance when it has one.

SPL tokens are detected assets: unverified, so hidden until reviewed, as on the other
platforms.

Tests: `SolanaRpcBalanceSyncTests`
(`testPortfolioRead_whenOneTokenProgramCannotBeRead_thenSolLoadsAndNoPartialTokenListIsReported`),
`SolanaRpcClientTests.testPortfolioBalances_whenNoNodeServesTokenAccounts_thenSolStillLoads`,
`AccountInfoRemoteServiceTests`
(`testFetchAccountInfos_whenSolanaTokenAccountsCannotBeRead_thenTheScanFailsWithFreshSolAndTheTokensLastKnown`,
`testDiscoveryScan_whenSolanaTokenAccountsCannotBeRead_thenTheNetworkSaysItsBalancesWereNotUpdated`,
`testRefusedSolanaTokenLookups_thenTheOverviewKeepsTokensAndSendNeverSeesAnOlderTokenAmount`),
`SendDependencyErrorSurfacingTests.testSendScreen_whenTheBalanceCannotBeRead_thenNoAmountIsShown`,
and on the local validator
`testEveryNodeBlocksTokenLookups_thenThePortfolioStillShowsSolAndKeepsTokensUnread`.

## History

The SORA Solana indexer (`si.soramitsu.io`) is used for history only when it proves, through
its service-info, that it serves the wallet's cluster; it serves Solana testnet, and its
service-info and account routes answer 404. Rows from it are therefore never shown on mainnet
today, and rows from an indexer for another cluster are never shown at all. Whenever the app
has no rows for the wallet (404, another cluster, an outage, or no transfers yet), the history
screen says "See your full Solana history on Solscan" and offers "View on explorer", which opens
`https://solscan.io/account/<address>` (`?cluster=devnet` on devnet), the address page the
browser extension links to. It never ends in an empty list or a "not supported" notice. The
receipt after a send shows the signature, which the unknown-outcome sheets also let the user
copy.

Tests: `WalletTransactionHistoryTests`
(`testSolanaHistoryWithoutRows_offersSolscanInsteadOfAnEmptyListOrNotSupported`,
`testSolanaHistoryWithVerifiedRows_showsThemWithoutTheExplorerNotice`,
`testSolanaHistory_whenTheIndexerHasNothing_thenTheInteractorAndPresenterOfferSolscan`,
`testSolanaAndBitcoinHistoryOfferTheExplorerOfTheWalletsAddress`),
`SolanaHistoryOperationFactoryTests.testIndexerThatIsMissingOrOnAnotherCluster_neverSuppliesMainnetRows`.

Send and Confirm read the SOL balance as well when sending a token, because the fee (and any
token account the transfer opens) is paid in SOL.

## Recipients

On the Send screen a Solana recipient must be a base58 key of 32 bytes
(`AddressChainDefiner.validateUniversalAddress`); the wallet's own address is recognised as
such. Anything else is "Invalid address for the selected network" before Continue opens
Confirm.

Before anything is signed, `SolanaRecipientValidator` checks the recipient against the chain:

| Recipient | SOL | SPL token |
|---|---|---|
| A wallet address (on the ed25519 curve, not owned by a token program, not a program), whether or not it has received anything yet | sent | sent; its associated token account is created if needed |
| An off-curve system account (a multisig vault at a program-derived address) | sent | refused: "This is a token account, not a wallet" |
| A token account (an associated token account is off curve; a keypair token account is owned by Token or Token-2022) | refused | refused |
| A program (executable account) | refused: "This is a program, not a wallet" | refused |
| Not a 32-byte base58 key | refused: "This isn't a Solana address" | refused |

Sending tokens to a token account would create a second token account owned by the first,
and nobody holds a key for it: the tokens would be lost. Every refusal says "Nothing was
sent" and asks the user for the recipient's Solana wallet address. The Send screen shows the
reason as soon as the fee quote finds it, once per address.

Tests: `SolanaRecipientSafetyTests` (`testOffCurveRecipientRejectedForTokenSend`, using the
USDC associated token account of `HAgk14…` that `solana find-program-derived-address`
derives; `testTokenProgramOwnedRecipientRejected`; `testProgramRecipientRejected`;
`testRegularWalletRecipientAccepted`; `testOffCurveSystemAccountAcceptedForSolOnly`;
`testTokenSendToTokenAccount_thenNothingIsSignedOrSent`),
`SendDependencyErrorSurfacingTests.testSendScreen_whenTheFeeQuoteFindsATokenAccount_thenExplainsOncePerAddress`,
`UniversalWalletAccountAddressResolverTests.testSolanaRecipientValidationAcceptsSolanaKeysAndDetectsOwnAddress`,
and on the local validator
`testSplSend_opensTheRecipientsTokenAccountOnceAndRefusesTokenAccountRecipients` and
`testSendAndConfirmScreens_pastedRecipientAndTypedAmount_payOnceOnTheValidator`, which pastes
the recipient and types the amount into the app's own Send screen, confirms on its Confirm
screen and checks that the validator moved the balance once.

## Rent

Solana refuses a transfer that opens an account with less than the rent-exempt minimum, or
that leaves the sender with more than zero but less than that minimum. The wallet reads the
minimum from the node (`getMinimumBalanceForRentExemption(0)`; 890,880 lamports on the test
validator, 650,240 on mainnet on 2026-10-11) and refuses both before signing, with the amount
in the message ("Amount too small for a new account", "Leave more SOL or send it all").
"Max" leaves nothing and is accepted. A token transfer to a holder without a token account
also pays that account's rent (165 bytes); the quoted fee includes it, because it leaves the
wallet's SOL, and the confirm screen shows it on its own row, "Recipient account setup", marked
"Included in the network fee" (`SolanaTransferService.estimateFeeQuote`,
`SolanaTransferFeeBreakdownListener`). The row is absent when no account is opened.

Tests (deposit row): `SolanaSendServiceTests.testFeeQuoteNamesTheRecipientTokenAccountDepositSeparately`,
`WalletSendConfirmNetworkRowTests.testRecipientAccountDepositHasItsOwnRowOnlyWhenTheTransferOpensAnAccount`.

Tests: `SolanaRecipientSafetyTests.testNativeSendBelowRentToNewAccountRejectedWithSpecificError`,
`testSenderRemainderBelowRentRejected`, `testRentRulesAtTheirBoundaries`,
`SolanaSendServiceTests.testSolanaTransferServiceEstimatesFeeAndSendsStandardSPLToken`, and on
the local validator `testRentRules_refuseBeforeSigningWithTheValidatorsOwnMinimum`.

## Fee

The fee is `getFeeForMessage` of the exact message that is signed: the base fee per signature
plus a priority fee. The priority fee is set with ComputeBudget instructions (unit limit, then
unit price, before the transfer):

| Transfer | Unit limit |
|---|---|
| SOL | 2,000 |
| SPL token to an existing token account | 40,000 |
| SPL token that opens the recipient's token account | 100,000 |

The unit price is the 75th percentile of `getRecentPrioritizationFees` for the accounts the
transfer writes, at least 1,000 and at most 2,000,000 micro-lamports per unit, so the largest
transfer's priority fee is at most 0.0002 SOL. The quote is kept for two minutes per recipient
and asset, so the transfer pays the fee the user reviewed. A transaction that ran out of
units would fail in simulation, before anything is sent.

Tests: `SolanaTransferTransactionBuilderTests` (`testNativeTransferWithComputeBudgetPutsLimitThenPriceBeforeTheTransfer`,
`testTokenSendWithComputeBudgetKeepsTheBudgetProgramReadonlyAndFirst`,
`testPriorityFeeIsRoundedUpToWholeLamports`, `testPriorityFeeFollowsRecentFeesWithinBounds`),
and on the local validator `testSolSend_paysTheQuotedFeeWithItsPriorityFeeAndTheExactAmount`
(the validator charges exactly the quoted 5,002 lamports).

## Tokens

SOL and standard SPL Token transfers are supported (`TransferChecked`, with an idempotent
associated-token-account create when the recipient has none). A token held under Token-2022
is refused with "This token can't be sent yet … It stays in your wallet, and you can still
receive it", because its extensions (transfer fees, hooks) need review screens this version
does not have. The source is the wallet's associated token account for the mint, or else the
account holding the most of it; a transfer larger than one account holds is refused ("Not
enough tokens").

## A broadcast whose outcome is unknown (double-pay guard)

Every transfer is simulated (with signature verification) before it is sent. Before the
signed transaction leaves the device it is recorded in `SolanaPendingBroadcastStore`
(`UserDefaults`, key `solana.pending_broadcast:<walletId>:<chainId>`): signature, signed
transaction and its last valid block height. It is public data once broadcast and holds no key
material. If the record cannot be written, nothing is broadcast.

Each node's answer to the broadcast is classified (`SolanaBroadcastAttemptOutcome`):

- **not sent**: no connection, DNS or TLS failure, HTTP 401/403/404/405/413/429 before the
  node read it, or a node that cannot take a transaction (-32601 no such method; -32004,
  -32005, -32014, -32016 behind or missing state). The next node is asked;
- **refused**: the node judged the transaction before relaying it (-32002 preflight failure,
  -32003 signature failure, -32600 or -32602 invalid request or bytes, -32700 undecodable).
  No other node is asked: every node would judge the same bytes the same way;
- **ambiguous**: a timeout, a dropped connection, a 5xx, an unreadable reply, or any other
  JSON-RPC error (-32603 internal error, the -32000 to -32099 server range, gateway quota and
  auth codes, anything unexpected). The node may have relayed it, so the next nodes get the
  same bytes with preflight skipped: a simulation would only see the copy on its way.

If no node may have forwarded a first attempt, the record is removed and the user is told the
transfer was not sent and why. Otherwise the wallet polls signature statuses for up to 30
seconds:

- confirmed without an error → sent;
- confirmed with an error → "The transfer failed": the amount did not move, the fee was paid;
- the blockhash expired with no trace, proved by two distinct hosts, for a record signed less
  than six hours ago → "This transfer wasn't sent", the record is removed;
- expired, but proved by one host only, or for an older record → "This transfer could not be
  verified": the record is released, nothing is retried, and the user is asked to check the
  balance and look the transaction up on Solscan before sending again. A node whose backend
  lacks the slot's history answers nothing for a transaction that landed, and nodes keep only
  hours to days of history (about 9 h on mainnet-beta, 22 h on Vibe Station, 50 h on
  publicnode), so one host, or an old record, cannot prove that nothing left the wallet;
- still unknown → "Transfer status is unknown" with **Retry sending** (the same signed bytes,
  the same signature, so it can land at most once) and **Copy transaction ID**. A node that
  accepted it but has not confirmed it yet is reported as sent, and the record stays until it
  lands or expires.

While a record exists, `submit` signs nothing new. It first asks the nodes what happened:
landed → the user is told the earlier transfer was sent (if they were told its outcome was
unknown) and nothing new is sent; expired as above → the record is cleared and the new
transfer goes ahead (or, if the user had been told it was sent, they are told it did not go
through); expired but unverified → the record is released, the new transfer stops with "Your
earlier transfer could not be verified" (check the balance and Solscan), and confirming again
sends it; otherwise "An earlier transfer is still in progress". A Solana transaction can only land until
its blockhash expires (about 150 blocks, roughly a minute), so a record resolves within
minutes; nothing is forgotten on a timer. A lookup that fails is never taken as "not sent". A
record that cannot be decoded is moved aside (`solana.pending_broadcast.unreadable:…`) and
does not lock the wallet's Solana. One transfer per wallet and network is in flight at a time.

Tests: `SolanaRecipientSafetyTests` (`testAmbiguousBroadcastResolvedBySignatureStatus`,
`testExpiredBlockhashWithoutSignatureReportsNotSent`,
`testExpiry_whenOneHostProvesIt_thenTheTransferIsUnverifiedAndTheRecordIsReleased`,
`testPriorRecord_whenOneHostProvesItsExpiry_thenTheNextSendStopsOnceAndThenGoesAhead`,
`testPriorRecord_whenTwoHostsProveItsExpiry_thenOnlyARecentRecordIsNotSent`,
`testUnknownOutcome_thenNextTransferIsRefusedBeforeSigning`,
`testRetryResendsTheSameBytesAndLandsOnce`, `testRetryRefusal_thenTheChainDecides`,
`testFirstAttemptRefusedOrUnreachable_thenNotSentAndRecordCleared`,
`testFirstSubmission_whenEveryNodeMayHaveRelayedIt_thenTheOutcomeIsUnknownAndTheRecordStays`,
`testFirstSubmission_whenTheFirstNodeJudgesIt_thenRejectedAndNoOtherNodeIsAsked`,
`testRecordThatCannotBeWritten_thenNothingIsBroadcast`,
`testAcceptedButUnconfirmed_thenReportedSentAndCheckedBeforeTheNextTransfer`,
`testUnknownOutcomeThatLandedLater_thenUserIsTold`,
`testLandedButFailedOnChain_thenReportedAsFailedNotSent`,
`testLookupFailure_thenPriorTransferStaysUnresolved`, the pending-record tests), the Solana
sheet tests in `SendDependencyErrorSurfacingTests`, and on the local validator
`testLostBroadcastReply_thenTheSignatureStatusSettlesItWithOnePayment`,
`testUnreachableBroadcast_thenUnknownOutcome_nothingNewIsSigned_andRetryLandsOnce`,
`testUnreachableBroadcast_whenTheBlockhashExpires_thenTheNextTransferIsTheOnlyPayment`.

## User-facing strings

These Solana messages are in the eight localizations the app ships (en, id, ja, pt-PT, ru,
tr, vi, zh-Hans): every `solana.transfer.*` key, `send.unavailable.solana_paused.*`, the
`send.unavailable.*` keys a Solana transfer can reach (`network.title`, `asset.message`,
`account.*`, `not_prepared.*`) and `wallet.transaction.history.solana.explorer.message`. The
code keeps the English text as the fallback (`NSLocalizedString(value:)`, decision D14). The
other `send.unavailable.*` keys (`bitcoin_paused.*`, `ton_wallet.*`, `iroha.message`) are not
Solana copy and are still English-only fallbacks, and the shipped tables are not otherwise
complete (pt-PT has fewer keys than en).

The table follows the locale the way iOS matches a preferred language to the app's
localizations (`Bundle.localizationBundle(for:)`, `Bundle.preferredLocalizations`): `en_US`
reads en, `zh_CN`, `zh-CN`, `zh-SG` and `zh-Hans-CN` read zh-Hans, `pt-BR` reads pt-PT, `in`
reads id, and a language the app does not ship reads English, never the device language.

Tests: `SolanaLocalizationCoverageTests` (every listed key in every shipped language with the
English placeholders, the refusals and the paused-send sheet in the selected language, and
`testLocalesReadTheShippedTableIOSWouldPick`).

## Before the staged rollout

A small funded mainnet canary per platform remains a team task in the release checklist; no
automated test sends on mainnet or a public testnet.
