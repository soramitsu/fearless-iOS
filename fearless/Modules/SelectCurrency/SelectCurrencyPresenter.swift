import Foundation
import SoraFoundation

final class SelectCurrencyPresenter {
    // MARK: Private properties

    private weak var view: SelectCurrencyViewInput?
    private let router: SelectCurrencyRouterInput
    private let interactor: SelectCurrencyInteractorInput
    private let viewModelFactory: SelectCurrencyViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        interactor: SelectCurrencyInteractorInput,
        router: SelectCurrencyRouterInput,
        viewModelFactory: SelectCurrencyViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel(with selectedCurrency: Currency) {
        let viewModel = viewModelFactory.buildViewModel(selected: selectedCurrency)
        view?.didRecieve(viewModel: viewModel)
    }
}

// MARK: - SelectCurrencyViewOutput

extension SelectCurrencyPresenter: SelectCurrencyViewOutput {
    func didLoad(view: SelectCurrencyViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didSelect(viewModel: SelectCurrencyCellViewModel) {
        guard let currency = Currency(rawValue: viewModel.title.lowercased()) else { return }
        interactor.didSelect(currency)
        router.proceed(from: view)
    }
}

// MARK: - SelectCurrencyInteractorOutput

extension SelectCurrencyPresenter: SelectCurrencyInteractorOutput {
    func didRecieve(selectedCurrency: Currency) {
        provideViewModel(with: selectedCurrency)
    }
}

// MARK: - Localizable

extension SelectCurrencyPresenter: Localizable {
    func applyLocalization() {}
}

extension SelectCurrencyPresenter: SelectCurrencyModuleInput {}
