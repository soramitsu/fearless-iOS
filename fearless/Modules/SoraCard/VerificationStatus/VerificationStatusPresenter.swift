import Foundation
import SoraFoundation

final class VerificationStatusPresenter {
    // MARK: Private properties

    private weak var view: VerificationStatusViewInput?
    private let router: VerificationStatusRouterInput
    private let interactor: VerificationStatusInteractorInput
    private let logger: LoggerProtocol
    private let supportURL: URL
    private let viewModelFactory: VerificationStatusViewModelFactoryProtocol
    private var status: SCKYCUserStatus?
    private var hasFreeAttempts: Bool = false

    // MARK: - Constructors

    init(
        interactor: VerificationStatusInteractorInput,
        router: VerificationStatusRouterInput,
        logger: LoggerProtocol,
        supportUrl: URL,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: VerificationStatusViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        supportURL = supportUrl
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

    func didTapSupportButton() {
        guard let view = view else { return }
        router.showWeb(
            url: supportURL,
            from: view,
            style: .automatic
        )
    }

    func didTapActionButton() {
        switch status {
        case .none:
            Task { await self.interactor.resetKYC() }
        case .notStarted, .userCanceled:
            Task { await self.interactor.retryKYC() }
        case .rejected:
            if hasFreeAttempts {
                Task { await self.interactor.retryKYC() }
            } else {
                router.dismiss(view: view)
                EventCenter.shared.notify(with: KYCReceivedFinalStatus())
            }
        case .pending, .successful:
            router.dismiss(view: view)
            EventCenter.shared.notify(with: KYCReceivedFinalStatus())
        }
    }

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

    func didReceive(status: SCKYCUserStatus?, hasFreeAttempts: Bool) {
        self.status = status
        self.hasFreeAttempts = hasFreeAttempts

        view?.didStopLoading()

        let statusViewModel = viewModelFactory.buildStatusViewModel(from: status, hasFreeAttempts: hasFreeAttempts)
        view?.didReceive(status: statusViewModel)
    }

    func resetKYC() {
        router.dismiss(view: view)
    }
}

// MARK: - Localizable

extension VerificationStatusPresenter: Localizable {
    func applyLocalization() {}
}

extension VerificationStatusPresenter: VerificationStatusModuleInput {}
