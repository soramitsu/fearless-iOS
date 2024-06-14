import Foundation
import SoraFoundation
import SSFModels

final class LiquidityPoolsOverviewPresenter {
    // MARK: Private properties

    private weak var view: LiquidityPoolsOverviewViewInput?
    private let router: LiquidityPoolsOverviewRouterInput
    private let interactor: LiquidityPoolsOverviewInteractorInput
    private let chain: ChainModel
    private let wallet: MetaAccountModel

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolsOverviewInteractorInput,
        router: LiquidityPoolsOverviewRouterInput,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.chain = chain
        self.wallet = wallet

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

    func backButtonClicked() {
        router.dismiss(view: view)
    }
}

// MARK: - LiquidityPoolsOverviewInteractorOutput

extension LiquidityPoolsOverviewPresenter: LiquidityPoolsOverviewInteractorOutput {}

// MARK: - Localizable

extension LiquidityPoolsOverviewPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolsOverviewPresenter: LiquidityPoolsOverviewModuleInput {}

extension LiquidityPoolsOverviewPresenter: LiquidityPoolsListModuleOutput {
    func didTapMoreUserPools() {
        router.showAllUserPools(chain: chain, wallet: wallet, from: view, moduleOutput: self)
    }

    func didTapMoreAvailablePools() {
        router.showAllAvailablePools(chain: chain, wallet: wallet, from: view, moduleOutput: self)
    }

    func shouldShowUserPools(_ shouldShow: Bool) {
        view?.changeUserPoolsVisibility(visible: shouldShow)
    }
}
