import UIKit

final class WalletTransactionDetailsInteractor {
    let transaction: AssetTransactionData
    weak var presenter: WalletTransactionDetailsInteractorOutputProtocol?

    init(transaction: AssetTransactionData) {
        self.transaction = transaction
    }
}

extension WalletTransactionDetailsInteractor: WalletTransactionDetailsInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveTransaction(transaction)
    }
}
