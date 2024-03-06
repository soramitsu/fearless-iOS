import SSFModels
import SSFUtils

final class TokensLocksRequestBuilder {
    func buildRequest(for chainAsset: ChainAsset, accountId: AccountId, currencyId: CurrencyId) -> any StorageRequest {
        chainAsset.chain.isReef ? TokensLocksRequest(accountId: accountId.toHex(), currencyId: currencyId) : TokensLocksRequest(accountId: accountId, currencyId: currencyId)
    }
}
