import UIKit

final class WalletChainAccountDashboardInteractor {
    weak var presenter: WalletChainAccountDashboardInteractorOutputProtocol!
}

extension WalletChainAccountDashboardInteractor: WalletChainAccountDashboardInteractorInputProtocol {}
