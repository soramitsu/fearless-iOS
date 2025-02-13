import UIKit
import RobinHood
import SSFModels

final class SelectAssetInteractor {
    // MARK: - Private properties

    private weak var output: SelectAssetInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let wallet: MetaAccountModel
    private let accountInfoFetchingProvider: AccountInfoFetching

    private var chainAssets: [ChainAsset]?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoFetchingProvider: AccountInfoFetching,
        chainAssets: [ChainAsset]?,
        wallet: MetaAccountModel
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        self.chainAssets = chainAssets
        self.wallet = wallet
    }
}

// MARK: - SelectAssetInteractorInput

extension SelectAssetInteractor: SelectAssetInteractorInput {
    func setup(with output: SelectAssetInteractorOutput) {
        self.output = output
    }
    
    func fetchChainAssets() {
        if let chainAssets = self.chainAssets {
            output?.didReceiveChainAssets(result: .success(chainAssets))
            return
        }
        chainAssetFetching.fetch(
            shouldUseCache: true,
            filters: [.enabled(wallet: wallet)],
            sortDescriptors: []
        ) { [weak self] result in
            guard let result = result else {
                return
            }

            switch result {
            case let .success(chainAssets):
                self?.chainAssets = chainAssets
                self?.output?.didReceiveChainAssets(result: .success(chainAssets))
                if chainAssets.isEmpty {
                    self?.output?.didReceiveChainAssets(result: .failure(BaseOperationError.parentOperationCancelled))
                }
            case let .failure(error):
                self?.output?.didReceiveChainAssets(result: .failure(error))
            }
        }
    }

    func update(with chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
        output?.didReceiveChainAssets(result: .success(chainAssets))

        if chainAssets.isEmpty {
            output?.didReceiveChainAssets(result: .failure(BaseOperationError.parentOperationCancelled))
            return
        }
    }

    func fetchAccountInfos(with chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?] {
        try await accountInfoFetchingProvider.fetchByUniqKey(for: chainAssets, wallet: wallet)
    }
}
