import Foundation
import RobinHood

protocol PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        dependingOn historyRangeOperation: BaseOperation<ChainHistoryRange>
    ) -> CompoundOperationWrapper<[AccountId]>
}
