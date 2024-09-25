import Foundation
import SSFModels

class OKXMultichainAssetFetching: MultichainAssetFetching {
    private let sourceChainId: String?
    private let okxService: OKXDexAggregatorService

    init(okxService: OKXDexAggregatorService, sourceChainId: String?) {
        self.okxService = okxService
        self.sourceChainId = sourceChainId
    }

    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset] {
        guard chain.isSora == false else {
            return chain.chainAssets
        }

        let params = OKXDexAllTokensRequestParameters(chainId: chain.chainId)

        let okxTokens = try await okxService.fetchAllTokens(parameters: params).data
        let allChainAssets: [ChainAsset] = okxTokens.compactMap {
            guard let decimals = $0.decimals, let precision = UInt16(decimals) else {
                return nil
            }

            let iconURL = $0.tokenLogoUrl.flatMap { URL(string: $0) }
            let isUtility = $0.tokenSymbol.uppercased() == chain.utilityAssets().first?.symbol.uppercased()
            let ethereumType: EthereumAssetType = isUtility ? .normal : .erc20

            let asset = AssetModel(
                id: $0.tokenContractAddress,
                name: $0.tokenName.or($0.tokenSymbol),
                symbol: $0.tokenSymbol,
                precision: precision,
                icon: iconURL,
                isUtility: isUtility,
                isNative: false,
                ethereumType: ethereumType
            )
            return ChainAsset(chain: chain, asset: asset)
        }

        return allChainAssets
    }
}
