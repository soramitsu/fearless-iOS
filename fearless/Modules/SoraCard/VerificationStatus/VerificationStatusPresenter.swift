import Foundation
import SoraFoundation

final class VerificationStatusPresenter {
    // MARK: Private properties

    private weak var view: VerificationStatusViewInput?
    private let router: VerificationStatusRouterInput
    private let interactor: VerificationStatusInteractorInput
    private let logger: LoggerProtocol
    private let viewModelFactory: VerificationStatusViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        interactor: VerificationStatusInteractorInput,
        router: VerificationStatusRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: VerificationStatusViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - VerificationStatusViewOutput

extension VerificationStatusPresenter: VerificationStatusViewOutput {
    func didLoad(view: VerificationStatusViewInput) {
        self.view = view
        interactor.setup(with: self)

        interactor.getKYCStatus()

        view.didStartLoading()
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }

    func didTapTryagainButton() {}

    func didTapRefresh() {
        view?.didStartLoading()
        interactor.getKYCStatus()
    }
}

// MARK: - VerificationStatusInteractorOutput

extension VerificationStatusPresenter: VerificationStatusInteractorOutput {
    func didReceive(error: Error) {
        view?.didStopLoading()

        logger.error(error.localizedDescription)
        view?.didReceive(error: error)
    }

    func didReceive(status: SCVerificationStatus) {
        view?.didStopLoading()

        let statusViewModel = viewModelFactory.buildStatusViewModel(from: status)
        view?.didReceive(status: statusViewModel)
    }
}

// MARK: - Localizable

extension VerificationStatusPresenter: Localizable {
    func applyLocalization() {}
}

extension VerificationStatusPresenter: VerificationStatusModuleInput {}
