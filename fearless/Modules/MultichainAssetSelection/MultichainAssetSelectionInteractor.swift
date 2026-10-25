import UIKit
import SSFModels

protocol MultichainAssetSelectionInteractorOutput: AnyObject {}

final class MultichainAssetSelectionInteractor {
    // MARK: - Private properties

    private weak var output: MultichainAssetSelectionInteractorOutput?
    private let chainFetching: MultichainChainFetching
    private let assetFetching: MultichainAssetFetching

    init(chainFetching: MultichainChainFetching, assetFetching: MultichainAssetFetching) {
        self.chainFetching = chainFetching
        self.assetFetching = assetFetching
    }
}

// MARK: - MultichainAssetSelectionInteractorInput

extension MultichainAssetSelectionInteractor: MultichainAssetSelectionInteractorInput {
    func setup(with output: MultichainAssetSelectionInteractorOutput) {
        self.output = output
    }

    func fetchChains() async throws -> [ChainModel] {
        try await chainFetching.fetchChains()
    }

    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset] {
        try await assetFetching.fetchAssets(for: chain)
    }
}
