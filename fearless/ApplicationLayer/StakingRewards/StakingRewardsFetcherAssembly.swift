import Foundation
import FearlessFoundation
import SSFModels

final class StakingRewardsFetcherAssembly {
    private let worker: NetworkWorkerDefault
    private let localizationManager: LocalizationManagerProtocol

    init(
        worker: NetworkWorkerDefault = NetworkWorkerDefault(),
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) {
        self.worker = worker
        self.localizationManager = localizationManager
    }

    func fetcher(for chain: ChainModel) throws -> StakingRewardsFetcher {
        let blockExplorer = chain.externalApi?.staking
        let type = blockExplorer?.type ?? .subsquid

        switch type {
        case .subquery:
            return SubqueryStakingRewardsFetcher(chain: chain, worker: worker)
        case .subsquid:
            return SubsquidStakingRewardsFetcher(
                chain: chain,
                worker: worker,
                localizationManager: localizationManager
            )
        case .giantsquid:
            return GiantsquidStakingRewardsFetcher(
                chain: chain,
                worker: worker,
                localizationManager: localizationManager
            )
        case .sora:
            return SoraStakingRewardsFetcher(
                chain: chain,
                worker: worker,
                localizationManager: localizationManager
            )
        case .reef:
            return ReefStakingRewardsFetcher(chain: chain, worker: worker)
        default:
            throw StakingRewardsFetcherError.missingBlockExplorer(chain: chain.name)
        }
    }
}
