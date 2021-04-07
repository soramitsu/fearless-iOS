import UIKit

final class WalletHistoryFilterInteractor {
    weak var presenter: WalletHistoryFilterInteractorOutputProtocol!
}

extension WalletHistoryFilterInteractor: WalletHistoryFilterInteractorInputProtocol {}
