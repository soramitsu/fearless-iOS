import Foundation
import RobinHood
import SSFModels

enum PayoutValidatorsFactoryAssembly {
    static func createPayoutValidatorsFactory(chainAsset: ChainAsset) -> PayoutValidatorsFactoryProtocol? {
        guard let blockExplorer = chainAsset.chain.externalApi?.staking else {
            return nil
        }

        let type = blockExplorer.type

        switch type {
        case .subquery:
            return SubqueryPayoutValidatorsForNominatorFactory(url: blockExplorer.url, chainAsset: chainAsset)
        case .subsquid, .reef:
            return SubsquidPayoutValidatorsForNominatorFactory(url: blockExplorer.url, chainAsset: chainAsset)
        case .sora:
            return SoraSubsquidPayoutValidatorsForNominatorFactory(url: blockExplorer.url, chainAsset: chainAsset)
        default:
            return SubsquidPayoutValidatorsForNominatorFactory(url: blockExplorer.url, chainAsset: chainAsset)
        }
    }
}

protocol PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        eraRangeClosure: @escaping () throws -> EraRange?
    ) -> CompoundOperationWrapper<[AccountId]>
}
