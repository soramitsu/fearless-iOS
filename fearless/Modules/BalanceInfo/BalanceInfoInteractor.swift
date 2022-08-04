import UIKit

final class BalanceInfoInteractor {
    // MARK: - Private properties

    private weak var output: BalanceInfoInteractorOutput?

    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol

    init(walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol) {
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
    }
}

// MARK: - BalanceInfoInteractorInput

extension BalanceInfoInteractor: BalanceInfoInteractorInput {
    func setup(with output: BalanceInfoInteractorOutput) {
        self.output = output
    }

    func fetchBalance(for type: BalanceInfoType) {
        switch type {
        case let .wallet(metaAccount):
            walletBalanceSubscriptionAdapter.subscribeWalletBalance(
                walletId: metaAccount.metaId,
                deliverOn: .main,
                handler: self
            )
        case let .chainAsset(metaAccount, chainAsset):
            walletBalanceSubscriptionAdapter.subscribeChainAssetBalance(
                walletId: metaAccount.metaId,
                chainAsset: chainAsset,
                deliverOn: .main,
                handler: self
            )
        }
    }
}

// MARK: - WalletBalanceSubscriptionHandler

extension BalanceInfoInteractor: WalletBalanceSubscriptionHandler {
    func handle(result: WalletBalancesResult) {
        output?.didReceiveWalletBalancesResult(result)
    }
}
