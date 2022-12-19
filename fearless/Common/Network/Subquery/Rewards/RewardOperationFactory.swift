import Foundation
import RobinHood

final class RewardOperationFactory {
    static func factory(type: ExternalApiType, url: URL?) -> RewardOperationFactoryProtocol {
        switch type {
        case .subquery:
            return SubqueryRewardOperationFactory(url: url)
        case .subsquid:
            return SubsquidRewardOperationFactory(url: url)
        }
    }
}

protocol RewardOperationFactoryProtocol {
    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData>

    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryDelegatorHistoryData>

    func createAprOperation(
        for idsClosure: @escaping () throws -> [AccountId],
        dependingOn roundIdOperation: BaseOperation<String>
    ) -> BaseOperation<SubqueryCollatorDataResponse>

    func createLastRoundOperation() -> BaseOperation<String>
}

extension RewardOperationFactoryProtocol {
    func createHistoryOperation(address: String) -> BaseOperation<SubqueryRewardOrSlashData> {
        createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil)
    }
}
