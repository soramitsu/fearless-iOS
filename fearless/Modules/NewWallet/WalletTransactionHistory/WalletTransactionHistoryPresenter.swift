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

    func loadNext() -> Bool {
        interactor.loadNext()
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryInteractorOutputProtocol {
    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    ) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        var viewModels = reload ? [] : self.viewModels
        let viewChanges = try? viewModelFactory.merge(
            newItems: pageData.transactions,
            into: &viewModels,
            locale: locale
        )

        guard let viewChanges = viewChanges else {
            return
        }

        self.viewModels = viewModels

        let viewModel = WalletTransactionHistoryViewModel(sections: viewModels, lastChanges: viewChanges)

        let state: WalletTransactionHistoryViewState = reload ? .reloaded(viewModel: viewModel) : .loaded(viewModel: viewModel)
        view?.didReceive(state: state)
    }
}

extension WalletTransactionHistoryPresenter: Localizable {
    func applyLocalization() {}
}
