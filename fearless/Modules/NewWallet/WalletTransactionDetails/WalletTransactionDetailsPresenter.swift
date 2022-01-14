import Foundation
import CommonWallet
import SoraFoundation

final class WalletTransactionDetailsPresenter {
    weak var view: WalletTransactionDetailsViewProtocol?
    let wireframe: WalletTransactionDetailsWireframeProtocol
    let interactor: WalletTransactionDetailsInteractorInputProtocol
    let viewModelFactory: WalletTransactionDetailsViewModelFactoryProtocol

    init(
        interactor: WalletTransactionDetailsInteractorInputProtocol,
        wireframe: WalletTransactionDetailsWireframeProtocol,
        viewModelFactory: WalletTransactionDetailsViewModelFactoryProtocol, localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

extension WalletTransactionDetailsPresenter: WalletTransactionDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension WalletTransactionDetailsPresenter: WalletTransactionDetailsInteractorOutputProtocol {
    func didReceiveTransaction(_ transaction: AssetTransactionData) {
        if let viewModel = viewModelFactory.buildViewModel(
            transaction: transaction,
            locale: selectedLocale
        ) {
            view?.didReceiveState(.loaded(viewModel: viewModel))
        } else {
            view?.didReceiveState(.empty)
        }
    }
}

extension WalletTransactionDetailsPresenter: Localizable {
    func applyLocalization() {}
}
