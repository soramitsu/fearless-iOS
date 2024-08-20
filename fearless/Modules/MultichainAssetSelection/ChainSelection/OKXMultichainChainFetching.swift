import Foundation
import SSFModels
import RobinHood

class OKXMultichainChainFetching: MultichainChainFetching {
    private let chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>

    init(chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>) {
        self.chainsRepository = chainsRepository
    }

    func fetchChains() async throws -> [ChainModel] {
        try await chainsRepository.fetchAll().filter { $0.rank != nil }
    }
}
