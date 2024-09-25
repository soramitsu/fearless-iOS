import Foundation
import SSFModels

enum MultichainChainFetchingFlow {
    case okxSource
    case okxDestination(sourceChainId: ChainModel.Id)
    case preset(chainIds: [ChainModel.Id])

    var contextTag: Int {
        switch self {
        case .okxSource:
            return 0
        case .okxDestination:
            return 1
        case .preset:
            return 0
        }
    }
}

protocol MultichainChainFetching {
    func fetchChains() async throws -> [ChainModel]
}
