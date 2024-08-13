import UIKit
import RobinHood
import SSFModels

final class SelectAssetInteractor {
    // MARK: - Private properties

    private weak var output: SelectAssetInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let wallet: MetaAccountModel

    private var chainAssets: [ChainAsset]?

    private lazy var accountInfosDeliveryQueue = {
        DispatchQueue(label: "co.jp.soramitsu.wallet.chainAssetList.deliveryQueue")
    }()

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAssets: [ChainAsset]?,
        wallet: MetaAccountModel
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.chainAssets = chainAssets
        self.wallet = wallet
    }

    private func fetchChainAssets() {
        if let chainAssets = self.chainAssets {
            subscribeToAccountInfo(for: chainAssets)
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
                self?.subscribeToAccountInfo(for: chainAssets)
            case let .failure(error):
                self?.output?.didReceiveChainAssets(result: .failure(error))
            }
        }
    }
}

// MARK: - SelectAssetInteractorInput

extension SelectAssetInteractor: SelectAssetInteractorInput {
    func setup(with output: SelectAssetInteractorOutput) {
        self.output = output
        fetchChainAssets()
    }
}

extension SelectAssetInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

private extension SelectAssetInteractor {
    func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: accountInfosDeliveryQueue
        )
    }
}
