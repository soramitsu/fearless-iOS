import Foundation
import SoraFoundation

final class SelectCurrencyPresenter {
    // MARK: Private properties

    private weak var view: SelectCurrencyViewInput?
    private let router: SelectCurrencyRouterInput
    private let interactor: SelectCurrencyInteractorInput
    private let viewModelFactory: SelectCurrencyViewModelFactoryProtocol

    private var selectedCurrency: Currency?
    private var supportedCurrencies: [Currency]?

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

    private func provideViewModel() {
        guard
            let supportedCurrencies = supportedCurrencies,
            let selectedCurrency = selectedCurrency
        else {
            return
        }

        let viewModel = viewModelFactory.buildViewModel(
            supportedCurrencies: supportedCurrencies,
            selectedCurrency: selectedCurrency
        )
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
        guard var currency = supportedCurrencies?.first(where: { $0.id == viewModel.id }) else { return }
        currency.isSelected = true
        interactor.didSelect(currency)
        router.proceed(from: view)
    }

    func back() {
        router.back(from: view)
    }
}

// MARK: - SelectCurrencyInteractorOutput

extension SelectCurrencyPresenter: SelectCurrencyInteractorOutput {
    func didRecieve(supportedCurrencies: Result<[Currency], Error>) {
        switch supportedCurrencies {
        case let .success(supportedCurrencies):
            self.supportedCurrencies = supportedCurrencies
            provideViewModel()
        case let .failure(error):
            router.present(error: error, from: view, locale: localizationManager?.selectedLocale)
        }
    }

    func didRecieve(selectedCurrency: Currency) {
        self.selectedCurrency = selectedCurrency
        provideViewModel()
    }
}

// MARK: - Localizable

extension SelectCurrencyPresenter: Localizable {
    func applyLocalization() {}
}

extension SelectCurrencyPresenter: SelectCurrencyModuleInput {}
