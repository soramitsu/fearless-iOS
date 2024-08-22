import Foundation
import SSFModels
import RobinHood

class OKXMultichainChainFetching: MultichainChainFetching {
    private let chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>
    private let okxService: OKXDexAggregatorService

    init(
        chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>,
        okxService: OKXDexAggregatorService
    ) {
        self.chainsRepository = chainsRepository
        self.okxService = okxService
    }

    func fetchChains() async throws -> [ChainModel] {
        let okxChainIds = try await okxService.fetchAvailableChains().data.map { "\($0.chainId)" }

        return try await chainsRepository.fetchAll().filter { okxChainIds.contains($0.chainId) }
    }
}
