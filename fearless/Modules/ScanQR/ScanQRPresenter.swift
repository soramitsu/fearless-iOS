import Foundation
import SoraFoundation

final class ScanQRPresenter {
    // MARK: Private properties

    private weak var view: ScanQRViewInput?
    private let router: ScanQRRouterInput
    private let interactor: ScanQRInteractorInput

    // MARK: - Constructors

    init(
        interactor: ScanQRInteractorInput,
        router: ScanQRRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - ScanQRViewOutput

extension ScanQRPresenter: ScanQRViewOutput {
    func didLoad(view: ScanQRViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - ScanQRInteractorOutput

extension ScanQRPresenter: ScanQRInteractorOutput {}

// MARK: - Localizable

extension ScanQRPresenter: Localizable {
    func applyLocalization() {}
}

extension ScanQRPresenter: ScanQRModuleInput {}
