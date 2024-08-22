import Foundation
import SSFModels

class OKXMultichainAssetFetching: MultichainAssetFetching {
    private let okxService: OKXDexAggregatorService

    init(okxService: OKXDexAggregatorService) {
        self.okxService = okxService
    }

    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset] {
        let params = OKXDexAllTokensRequestParameters(chainId: chain.chainId)
        let okxTokenSymbols = try await okxService.fetchAllTokens(parameters: params).data.map { $0.tokenSymbol.lowercased() }
        return chain.chainAssets.filter { okxTokenSymbols.contains($0.asset.symbol.lowercased()) }
    }
}
