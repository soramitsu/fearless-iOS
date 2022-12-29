import Foundation
import SoraFoundation

final class SoraCardInfoBoardPresenter {
    // MARK: Private properties

    private weak var view: SoraCardInfoBoardViewInput?
    private let router: SoraCardInfoBoardRouterInput
    private let interactor: SoraCardInfoBoardInteractorInput
    private let logger: LoggerProtocol?
    private let viewModelFactory: SoraCardStateViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        interactor: SoraCardInfoBoardInteractorInput,
        router: SoraCardInfoBoardRouterInput,
        logger: LoggerProtocol?,
        viewModelFactory: SoraCardStateViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - SoraCardInfoBoardViewOutput

extension SoraCardInfoBoardPresenter: SoraCardInfoBoardViewOutput {
    func didLoad(view: SoraCardInfoBoardViewInput) {
        self.view = view
        interactor.setup(with: self)

        didTapRefresh()

        view.didReceive(stateViewModel: .none)
    }

    func didTapGetSoraCard() {}

    func didTapKYCStatus() {}

    func didTapBalance() {}

    func didTapRefresh() {
        view?.didStartLoading()
        interactor.getKYCStatus()
    }
}

// MARK: - SoraCardInfoBoardInteractorOutput

extension SoraCardInfoBoardPresenter: SoraCardInfoBoardInteractorOutput {
    func didReceive(error: Error) {
        view?.didStopLoading()

        logger?.error(error.localizedDescription)
    }

    func didReceive(status: SCKYCStatusResponse) {
        view?.didStopLoading()

        let statusViewModel = viewModelFactory.buildState(from: status)
        view?.didReceive(stateViewModel: statusViewModel)
    }
}

// MARK: - Localizable

extension SoraCardInfoBoardPresenter: Localizable {
    func applyLocalization() {}
}

extension SoraCardInfoBoardPresenter: SoraCardInfoBoardModuleInput {}
