import Foundation
import SSFModels

class OKXMultichainAssetFetching: MultichainAssetFetching {
    private let sourceChainId: String?
    private let okxService: OKXDexAggregatorService

    init(okxService: OKXDexAggregatorService, sourceChainId: String?) {
        self.okxService = okxService
        self.sourceChainId = sourceChainId
    }

    func fetchAssets(for chain: ChainModel, preferredDataSourceType: PreferredDataSourceType) async throws -> [ChainAsset] {
        guard chain.isSora == false else {
            return chain.chainAssets
        }

        let params = OKXDexAllTokensRequestParameters(chainId: chain.chainId)

        let okxTokens = try await okxService.fetchAllTokens(parameters: params, preferredDataSourceType: preferredDataSourceType).data

        guard let okxTokens else {
            return []
        }

        let allChainAssets: [ChainAsset] = okxTokens.compactMap {
            guard let decimals = $0.decimals, let precision = UInt16(decimals) else {
                return nil
            }

            let isUtility = $0.tokenContractAddress == "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
            let contractAddress = $0.tokenContractAddress
            let nativeAsset = isUtility ? chain.utilityChainAssets().first : chain.chainAssets.first(where: { $0.asset.id.lowercased() == contractAddress.lowercased() })
            let id = nativeAsset?.asset.id ?? $0.tokenContractAddress

            let iconURL = $0.tokenLogoUrl.flatMap { URL(string: $0) }
            let ethereumType: EthereumAssetType = isUtility ? .normal : .erc20

            let asset = AssetModel(
                id: id,
                name: $0.tokenName.or($0.tokenSymbol),
                symbol: $0.tokenSymbol,
                precision: precision,
                icon: iconURL,
                currencyId: $0.tokenContractAddress,
                isUtility: isUtility,
                isNative: false,
                ethereumType: ethereumType
            )

            return ChainAsset(chain: chain, asset: asset)
        }

        return allChainAssets
    }
}
