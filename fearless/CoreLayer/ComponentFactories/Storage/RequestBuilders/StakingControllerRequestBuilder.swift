import Foundation
import SSFModels
import SSFUtils

final class StakingControllerRequestBuilder {
    func buildRequest(for chainAsset: ChainAsset, accountId: AccountId) -> any StorageRequest {
        chainAsset.chain.isReef ? StakingControllerRequest(accountId: accountId.toHex()) : StakingControllerRequest(accountId: accountId)
    }
}
