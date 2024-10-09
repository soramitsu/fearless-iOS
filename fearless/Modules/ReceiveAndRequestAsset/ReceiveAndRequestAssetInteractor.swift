import UIKit
import SSFModels

protocol ReceiveAndRequestAssetInteractorOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

final class ReceiveAndRequestAssetInteractor {
    // MARK: - Private properties

    private weak var output: ReceiveAndRequestAssetInteractorOutput?

    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let chainAsset: ChainAsset

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.chainAsset = chainAsset
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }
}

// MARK: - ReceiveAndRequestAssetInteractorInput

extension ReceiveAndRequestAssetInteractor: ReceiveAndRequestAssetInteractorInput {
    func setup(with output: ReceiveAndRequestAssetInteractorOutput) {
        self.output = output

        guard chainAsset.chain.isSora else {
            return
        }
        subscribeToAccountInfo(for: chainAsset.chain.chainAssets)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension ReceiveAndRequestAssetInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}
