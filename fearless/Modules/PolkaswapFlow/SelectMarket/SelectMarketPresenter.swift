import Foundation
import SoraFoundation

final class SelectMarketPresenter {
    // MARK: Private properties

    private weak var view: SelectMarketViewInput?
    private weak var moduleOutput: SelectMarketModuleOutput?
    private let router: SelectMarketRouterInput
    private let interactor: SelectMarketInteractorInput

    private let markets: [LiquiditySourceType]
    private var viewModels: [SelectableTitleListViewModel] = []

    // MARK: - Constructors

    init(
        markets: [LiquiditySourceType],
        moduleOutput: SelectMarketModuleOutput?,
        interactor: SelectMarketInteractorInput,
        router: SelectMarketRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.markets = markets
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        viewModels = markets.map {
            SelectableTitleListViewModel(title: $0.name)
        }

        view?.didReload()
    }
}

// MARK: - SelectMarketViewOutput

extension SelectMarketPresenter: SelectMarketViewOutput {
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        guard let market = markets[safe: index] else {
            return
        }
        moduleOutput?.didSelect(market: market)
        router.dismiss(view: view)
    }

    func didTapInfoButton(at index: Int) {
        guard let market = markets[safe: index] else {
            return
        }
        router.present(
            message: market.description,
            title: market.name,
            closeAction: nil,
            from: view
        )
    }

    func didLoad(view: SelectMarketViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - SelectMarketInteractorOutput

extension SelectMarketPresenter: SelectMarketInteractorOutput {}

// MARK: - Localizable

extension SelectMarketPresenter: Localizable {
    func applyLocalization() {}
}

extension SelectMarketPresenter: SelectMarketModuleInput {}
