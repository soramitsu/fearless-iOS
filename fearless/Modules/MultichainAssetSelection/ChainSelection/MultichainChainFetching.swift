import Foundation
import SSFModels

enum MultichainChainFetchingFlow {
    case okx
    case preset(chainIds: [ChainModel.Id])
}

protocol MultichainChainFetching {
    func fetchChains() async throws -> [ChainModel]
}
