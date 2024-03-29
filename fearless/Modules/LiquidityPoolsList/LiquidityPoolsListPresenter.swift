import Foundation
import SoraFoundation

final class LiquidityPoolsListPresenter {
    // MARK: Private properties

    private weak var view: LiquidityPoolsListViewInput?
    private let router: LiquidityPoolsListRouterInput
    private let interactor: LiquidityPoolsListInteractorInput

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolsListInteractorInput,
        router: LiquidityPoolsListRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - LiquidityPoolsListViewOutput

extension LiquidityPoolsListPresenter: LiquidityPoolsListViewOutput {
    func didLoad(view: LiquidityPoolsListViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - LiquidityPoolsListInteractorOutput

extension LiquidityPoolsListPresenter: LiquidityPoolsListInteractorOutput {}

// MARK: - Localizable

extension LiquidityPoolsListPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolsListPresenter: LiquidityPoolsListModuleInput {}
