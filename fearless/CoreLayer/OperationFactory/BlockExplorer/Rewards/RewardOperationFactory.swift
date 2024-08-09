import Foundation
import RobinHood
import BigInt
import SSFModels

protocol RewardHistoryResponseProtocol {
    func rewardHistory(for address: String) -> [RewardHistoryItemProtocol]
}

protocol RewardHistoryItemProtocol {
    var id: String { get }
    var type: SubqueryDelegationAction { get }
    var timestampInSeconds: String { get }
    var blockNumber: Int { get }
    var amount: BigUInt { get }
}

protocol CollatorAprInfoProtocol {
    var collatorId: String { get }
    var apr: Double { get }
}

protocol CollatorAprResponse {
    var collatorAprInfos: [CollatorAprInfoProtocol] { get }
}

enum RewardOperationFactory {
    static func factory(chain: ChainModel) -> RewardOperationFactoryProtocol {
        let blockExplorer = chain.externalApi?.staking
        let type = blockExplorer?.type ?? .subsquid

        switch type {
        case .subquery:
            return SubqueryRewardOperationFactory(url: blockExplorer?.url)
        case .subsquid:
            return ArrowsquidRewardOperationFactory(url: blockExplorer?.url)
        case .giantsquid:
            return GiantsquidRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        case .sora:
            return SoraRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        case .reef:
            return ReefRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        case .alchemy, .etherscan, .oklink, .zeta, .fire, .vicscan, .zchain, .klaytn:
            return GiantsquidRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        }
    }
}

protocol RewardOperationFactoryProtocol {
    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardOrSlashResponse>

    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol>

    func createAprOperation(
        for idsClosure: @escaping () throws -> [AccountId],
        dependingOn roundIdOperation: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse>

    func createLastRoundOperation() -> BaseOperation<String>
}

extension RewardOperationFactoryProtocol {
    func createHistoryOperation(address: String) -> BaseOperation<RewardOrSlashResponse> {
        createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil)
    }
}
