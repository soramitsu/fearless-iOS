import Foundation
import SoraFoundation

protocol CrossChainSwapConfirmViewInput: ControllerBackedProtocol {}

protocol CrossChainSwapConfirmInteractorInput: AnyObject {
    func setup(with output: CrossChainSwapConfirmInteractorOutput)
}

final class CrossChainSwapConfirmPresenter {
    // MARK: Private properties

    private weak var view: CrossChainSwapConfirmViewInput?
    private let router: CrossChainSwapConfirmRouterInput
    private let interactor: CrossChainSwapConfirmInteractorInput

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapConfirmInteractorInput,
        router: CrossChainSwapConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - CrossChainSwapConfirmViewOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmViewOutput {
    func didLoad(view: CrossChainSwapConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - CrossChainSwapConfirmInteractorOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmInteractorOutput {}

// MARK: - Localizable

extension CrossChainSwapConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmModuleInput {}
