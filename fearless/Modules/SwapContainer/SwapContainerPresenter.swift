import Foundation
import SoraFoundation
import SSFModels

protocol SwapContainerViewInput: ControllerBackedProtocol {
    func switchToPolkaswap()
    func switchToOkx()
}

final class SwapContainerPresenter {
    // MARK: Private properties

    private weak var view: SwapContainerViewInput?
    private let router: SwapContainerRouterInput

    weak var okxModuleInput: CrossChainSwapSetupModuleInput?
    weak var polkaswapModuleInput: PolkaswapAdjustmentModuleInput?

    // MARK: - Constructors

    init(
        router: SwapContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - SwapContainerViewOutput

extension SwapContainerPresenter: SwapContainerViewOutput {
    func didLoad(view: SwapContainerViewInput) {
        self.view = view
    }
}

// MARK: - Localizable

extension SwapContainerPresenter: Localizable {
    func applyLocalization() {}
}

extension SwapContainerPresenter: SwapContainerModuleInput {}

extension SwapContainerPresenter: CrossChainSwapSetupModuleOutput {
    func didSwitchToPolkaswap(with chainAsset: ChainAsset?) {
        polkaswapModuleInput?.didSelect(sourceChainAsset: chainAsset)
        view?.switchToPolkaswap()
    }
}

extension SwapContainerPresenter: PolkaswapAdjustmentModuleOutput {
    func didSwitchToOkx(with chainAsset: ChainAsset?) {
        okxModuleInput?.didSelect(sourceChainAsset: chainAsset)
        view?.switchToOkx()
    }
}
