import Foundation
import CommonWallet
import SoraFoundation

final class WalletTransactionHistoryPresenter {
    weak var view: WalletTransactionHistoryViewProtocol?
    let wireframe: WalletTransactionHistoryWireframeProtocol
    let interactor: WalletTransactionHistoryInteractorInputProtocol
    let viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol

    private(set) var viewModels: [WalletTransactionHistorySection] = []

    init(
        interactor: WalletTransactionHistoryInteractorInputProtocol,
        wireframe: WalletTransactionHistoryWireframeProtocol,
        viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryInteractorOutputProtocol {
    func didReceive(
        pageData: AssetTransactionPageData,
        andSwitch _: WalletTransactionHistoryDataState,
        reload: Bool
    ) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        var viewModels = reload ? [] : self.viewModels
        let viewChanges = viewModelFactory.merge(
            newItems: pageData.transactions,
            into: &viewModels,
            locale: locale
        )

        self.viewModels = viewModels

        let viewModel = WalletTransactionHistoryViewModel(sections: viewModels, lastChanges: viewChanges)

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension WalletTransactionHistoryPresenter: Localizable {
    func applyLocalization() {}
}
