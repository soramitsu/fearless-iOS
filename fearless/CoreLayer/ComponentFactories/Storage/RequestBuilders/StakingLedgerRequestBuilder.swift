import Foundation
import SSFModels
import SSFUtils

final class StakingLedgerRequestBuilder {
    func buildRequest(for chainAsset: ChainAsset, accountId: AccountId) -> any StorageRequest {
        chainAsset.chain.isReef ? StakingLedgerRequest(accountId: accountId.toHex()) : StakingLedgerRequest(accountId: accountId)
    }
}
