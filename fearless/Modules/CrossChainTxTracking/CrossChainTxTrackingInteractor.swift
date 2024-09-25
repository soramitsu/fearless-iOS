import UIKit
import SSFModels
import RobinHood

enum CrossChainTxTrackingInteractorError: Error {
    case invalidResponse
}

protocol CrossChainTxTrackingInteractorOutput: AnyObject {}

final class CrossChainTxTrackingInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainTxTrackingInteractorOutput?
    private let txHash: String
    private let chainAsset: ChainAsset
    private let okxService: OKXDexAggregatorService
    private let chainRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>

    init(
        txHash: String,
        chainAsset: ChainAsset,
        okxService: OKXDexAggregatorService,
        chainRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>
    ) {
        self.txHash = txHash
        self.chainAsset = chainAsset
        self.okxService = okxService
        self.chainRepository = chainRepository
    }
}

// MARK: - CrossChainTxTrackingInteractorInput

extension CrossChainTxTrackingInteractor: CrossChainTxTrackingInteractorInput {
    func setup(with output: CrossChainTxTrackingInteractorOutput) {
        self.output = output
    }

    func queryTransactionStatus() async throws -> OKXCrossChainTransactionStatus {
        let parameters = OKXDexCrossChainStatusParameters(hash: txHash)
        let response = try await okxService.fetchCrossChainTransactionStatus(parameters: parameters)

        guard let status = response.data.first else {
            throw CrossChainTxTrackingInteractorError.invalidResponse
        }

        return status
    }

    func queryChain(chainId: String) async throws -> SSFModels.ChainModel? {
        try await chainRepository.fetch(by: chainId, options: RepositoryFetchOptions())
    }

    func fetchChainAssets(chain: ChainModel) async throws -> [ChainAsset] {
        let parameters = OKXDexAllTokensRequestParameters(chainId: chain.chainId)
        let tokens = try await okxService.fetchAllTokens(parameters: parameters).data

        let allChainAssets: [ChainAsset] = tokens.compactMap {
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
