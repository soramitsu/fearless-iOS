import UIKit
import SSFModels
import BigInt

enum CrossChainSwapSetupInteractorError: Error {
    case cannotFindTokenAddress
    case accountNotFound
}

protocol CrossChainSwapSetupInteractorOutput: AnyObject {}

final class CrossChainSwapSetupInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainSwapSetupInteractorOutput?
    private let wallet: MetaAccountModel
    private let okxService: OKXDexAggregatorService

    init(
        okxService: OKXDexAggregatorService,
        wallet: MetaAccountModel
    ) {
        self.okxService = okxService
        self.wallet = wallet
    }
    
    private func getCrossChainQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount _: BigUInt) async throws -> [CrossChainSwap] {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }

        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: chainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters)

        guard
            let fromTokenAddress = fromTokens.data.first(where: { $0.tokenSymbol.lowercased() == chainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = toTokens.data.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let parameters = OKXDexCrossChainBuildTxParameters(
            fromChainId: chainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: "1478437000000000000",
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: 0,
            slippage: "0.01",
            userWalletAddress: address
        )

        let quotes = try await okxService.fetchSwapInfo(parameters: parameters)
        return quotes.data
    }
    
    private func getSameChainQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount _: BigUInt) async throws -> [CrossChainSwap] {
        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: chainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters)

        guard
            let fromTokenAddress = fromTokens.data.first(where: { $0.tokenSymbol.lowercased() == chainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = toTokens.data.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let parameters = OKXDexSwapRequestParameters(chainId: chainAsset.chain.chainId, amount: "11111111111", fromTokenAddress: fromTokenAddress, toTokenAddress: toTokenAddress, slippage: "0.01", userWalletAddress: <#T##String#>)

        let quotes = try await okxService.fetchSwapInfo(parameters: parameters)
        return quotes.data
    }
}

// MARK: - CrossChainSwapSetupInteractorInput

extension CrossChainSwapSetupInteractor: CrossChainSwapSetupInteractorInput {
    func setup(with output: CrossChainSwapSetupInteractorOutput) {
        self.output = output
    }

    func getQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount _: BigUInt) async throws -> [CrossChainSwap] {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            throw CrossChainSwapSetupInteractorError.accountNotFound
        }

        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: chainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        let toTokensParameters = OKXDexAllTokensRequestParameters(chainId: destinationChainAsset.chain.chainId)
        let toTokens = try await okxService.fetchAllTokens(parameters: toTokensParameters)

        guard
            let fromTokenAddress = fromTokens.data.first(where: { $0.tokenSymbol.lowercased() == chainAsset.asset.symbol.lowercased() })?.tokenContractAddress,
            let toTokenAddress = toTokens.data.first(where: { $0.tokenSymbol.lowercased() == destinationChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }

        let parameters = OKXDexCrossChainBuildTxParameters(
            fromChainId: chainAsset.chain.chainId,
            toChainId: destinationChainAsset.chain.chainId,
            amount: "1478437000000000000",
            fromTokenAddress: fromTokenAddress,
            toTokenAddress: toTokenAddress,
            sort: 0,
            slippage: "0.01",
            userWalletAddress: address
        )

        let quotes = try await okxService.fetchSwapInfo(parameters: parameters)
        return quotes.data
    }
}
