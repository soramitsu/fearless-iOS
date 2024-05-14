import Foundation
import SoraFoundation

final class LiquidityPoolDetailsPresenter {
    // MARK: Private properties

    private weak var view: LiquidityPoolDetailsViewInput?
    private let router: LiquidityPoolDetailsRouterInput
    private let interactor: LiquidityPoolDetailsInteractorInput

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolDetailsInteractorInput,
        router: LiquidityPoolDetailsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - LiquidityPoolDetailsViewOutput

extension LiquidityPoolDetailsPresenter: LiquidityPoolDetailsViewOutput {
    func didLoad(view: LiquidityPoolDetailsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - LiquidityPoolDetailsInteractorOutput

extension LiquidityPoolDetailsPresenter: LiquidityPoolDetailsInteractorOutput {}

// MARK: - Localizable

extension LiquidityPoolDetailsPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolDetailsPresenter: LiquidityPoolDetailsModuleInput {}
