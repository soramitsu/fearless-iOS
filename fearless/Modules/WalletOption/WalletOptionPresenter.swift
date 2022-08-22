import Foundation
import SoraFoundation

final class WalletOptionPresenter {
    // MARK: Private properties

    private weak var view: WalletOptionViewInput?
    private let router: WalletOptionRouterInput
    private let interactor: WalletOptionInteractorInput

    // MARK: - Constructors

    init(
        interactor: WalletOptionInteractorInput,
        router: WalletOptionRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - WalletOptionViewOutput

extension WalletOptionPresenter: WalletOptionViewOutput {
    func didLoad(view: WalletOptionViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - WalletOptionInteractorOutput

extension WalletOptionPresenter: WalletOptionInteractorOutput {}

// MARK: - Localizable

extension WalletOptionPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletOptionPresenter: WalletOptionModuleInput {}
