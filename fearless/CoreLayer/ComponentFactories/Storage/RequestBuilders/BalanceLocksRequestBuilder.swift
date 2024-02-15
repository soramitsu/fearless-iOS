import SSFModels
import SSFUtils

final class BalanceLocksRequestBuilder {
    func buildRequest(for chainAsset: ChainAsset, accountId: AccountId) -> any StorageRequest {
        chainAsset.chain.isReef ? BalancesLocksRequest(accountId: accountId.toHex()) : BalancesLocksRequest(accountId: accountId)
    }
}
