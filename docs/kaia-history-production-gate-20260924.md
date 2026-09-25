# iOS Kaia history provider migration and release gate

The legacy Kaia history factory called the configured `scope.klaytn` or
`scope.kaia` endpoint as `/accounts/{address}/txs`. The current Kaia Foundation
identifies KaiaScan as its official block explorer and points developers to its
OAPI. The native KaiaScan OAPI has documented account transactions and fungible
token transfers, so the iOS history factory now maps legacy Scope configuration
to the corresponding KaiaScan endpoint only for Kaia mainnet (chain ID 8217) or
Kairos (chain ID 1001). It also accepts the matching KaiaScan OAPI host. Other
hosts, chain identities, insecure URLs and missing credentials fail closed.

The request uses `Authorization: Bearer <FL_IOS_KAIASCAN_API_KEY>`, which the
Kaia Foundation's integration guide shows for native OAPI. The key is not put
in the URL. The iOS Release configuration audit requires this value. The mainnet
host is `mainnet-oapi.kaiascan.io`; the Kairos host is
`kairos-oapi.kaiascan.io`. Native history uses
`/api/v1/accounts/:accountAddress/transactions`; fungible token history uses
`/api/v1/accounts/:accountAddress/token-transfers` with `contractAddress`.
Both send explicit `page` and `size`, and the returned `paging.last` controls
the next page. A malformed response, wrong page, wrong token contract, HTTP
error or provider rejection remains an unavailable history state rather than
an empty wallet history. KaiaScan's documented zero-record sample reports
`current_page: 0`; the client accepts that shape only for an empty first page
with `last: true`, zero total count and zero total pages.

The native OAPI reports `amount` and `transaction_fee` as decimal currency
values, so the client decodes them as `Decimal` without the previous wei
conversion. Transaction `status` maps success/failure to committed/rejected.
The token-transfer response has no fee field; the UI leaves token transfer fees
unspecified instead of displaying a fabricated zero. Account transaction fees
may also be paid by a separate `fee_payer` under Kaia's delegated-fee model.
Rows where the wallet is only the fee payer are excluded from transfer amounts,
so someone else's payment cannot appear as an incoming wallet transfer. Funded
reconciliation must qualify fee-only activity and the intended UI treatment
before release.

Source contracts:

- [Kaia Foundation: KaiaScan explorer](https://docs.kaia.io/build/tools/block-explorers/kaiascan/)
- [Kaia Foundation: native OAPI Bearer request](https://blog.kaia.io/how-to-access-kaiachain-data-using-kaiascan-api/)
- [KaiaScan: account transactions](https://docs.kaiascan.io/api/Account/Transaction/get-account-transactions)
- [KaiaScan: fungible token transfers](https://docs.kaiascan.io/api/Account/Transfer/get-token-transfers)
- [KaiaScan: mainnet and Kairos endpoints](https://docs.kaiascan.io/etherscan-compatible-api)
- [KaiaScan: free-plan 500-record cap](https://docs.kaiascan.io/)

The remaining production gate is a real provisioned KaiaScan key, an exact
mainnet and Kairos registry route inventory, authenticated empty/error/page
responses recorded without credential disclosure, and funded native/token
transfer reconciliation against KaiaScan and the deployed chain. Synthetic
decoder/request tests and an accepted configuration shape do not prove provider
authorization, data freshness or recipient credit. Keep release acceptance
open until those checks pass against the final distributed binary.

On 2026-09-24, unauthenticated GET probes to the documented native account
transaction path returned HTTP 401 with JSON content type on both the mainnet
and Kairos hosts. This confirms that the hosts and paths respond, but does not
qualify authorization or the success payload.
