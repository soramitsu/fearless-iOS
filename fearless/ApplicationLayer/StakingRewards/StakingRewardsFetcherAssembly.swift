import Foundation
import SSFModels

enum StakingRewardsFetcherAssemblyError: Error {
    case noBlockExplorer(chainName: String)
}

final class StakingRewardsFetcherAssembly {
    func fetcher(for chain: ChainModel) throws -> StakingRewardsFetcher {
        let blockExplorer = chain.externalApi?.staking
        let type = blockExplorer?.type ?? .subsquid

        switch type {
        case .subquery:
            return SubqueryStakingRewardsFetcher(chain: chain)
        case .subsquid:
            return SubsquidStakingRewardsFetcher(chain: chain)
        case .giantsquid:
            return GiantsquidStakingRewardsFetcher(chain: chain)
        case .sora:
            return SoraStakingRewardsFetcher(chain: chain)
        case .reef:
            return ReefStakingRewardsFetcher(chain: chain)
        case .alchemy, .etherscan, .oklink, .zeta:
            throw StakingRewardsFetcherError.missingBlockExplorer(chain: chain.name)
        }
    }
}
