import Foundation
import SSFModels
import RobinHood

class CrossChainSwapMultichainChainFetching: MultichainChainFetching {
    private let chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>
    private let okxService: OKXDexAggregatorService
    private let sourceChainId: String?

    init(
        chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>,
        okxService: OKXDexAggregatorService,
        sourceChainId: String?
    ) {
        self.chainsRepository = chainsRepository
        self.okxService = okxService
        self.sourceChainId = sourceChainId
    }

    func fetchChains() async throws -> [ChainModel] {
        let appendSoraChain = sourceChainId == nil
        let okxChainIds = try await okxService.fetchAvailableChains().data.map { "\($0.chainId)" }

        let allChains: [ChainModel] = try await chainsRepository.fetchAll().filter { okxChainIds.contains($0.chainId) || ($0.isSora && appendSoraChain) }

        guard let sourceChainId else {
            return allChains
        }

        let availableDestinationParameters = OKXDexCrossChainSupportedBridgeTokensPairsParameters(fromChainId: sourceChainId)
        let availableDestinations = try await okxService.fetchAvailableDestinationTokens(parameters: availableDestinationParameters)
        let availableChainIds = availableDestinations.data.map { $0.toChainId }
        return allChains.filter { availableChainIds.contains($0.chainId) } + allChains.filter { $0.chainId == sourceChainId }
    }
}
