import Foundation
import SoraFoundation

final class LiquidityPoolsOverviewPresenter {
    // MARK: Private properties

    private weak var view: LiquidityPoolsOverviewViewInput?
    private let router: LiquidityPoolsOverviewRouterInput
    private let interactor: LiquidityPoolsOverviewInteractorInput

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolsOverviewInteractorInput,
        router: LiquidityPoolsOverviewRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - LiquidityPoolsOverviewViewOutput

extension LiquidityPoolsOverviewPresenter: LiquidityPoolsOverviewViewOutput {
    func didLoad(view: LiquidityPoolsOverviewViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - LiquidityPoolsOverviewInteractorOutput

extension LiquidityPoolsOverviewPresenter: LiquidityPoolsOverviewInteractorOutput {}

// MARK: - Localizable

extension LiquidityPoolsOverviewPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolsOverviewPresenter: LiquidityPoolsOverviewModuleInput {}
