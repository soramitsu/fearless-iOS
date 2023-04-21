import Foundation
import SoraFoundation

final class SoraCardInfoBoardPresenter {
    // MARK: Private properties

    private weak var view: SoraCardInfoBoardViewInput?
    private let router: SoraCardInfoBoardRouterInput
    private let interactor: SoraCardInfoBoardInteractorInput
    private let logger: LoggerProtocol?
    private let viewModelFactory: SoraCardStateViewModelFactoryProtocol
    private let wallet: MetaAccountModel
    private var moduleOutput: SoraCardInfoBoardModuleOutput?

    // MARK: - Constructors

    init(
        interactor: SoraCardInfoBoardInteractorInput,
        router: SoraCardInfoBoardRouterInput,
        logger: LoggerProtocol?,
        viewModelFactory: SoraCardStateViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - SoraCardInfoBoardViewOutput

extension SoraCardInfoBoardPresenter: SoraCardInfoBoardViewOutput {
    func didTapStart() {
        Task { [weak self] in await self?.interactor.prepareStart() }
    }

    func didLoad(view: SoraCardInfoBoardViewInput) {
        self.view = view
        interactor.setup(with: self)
        Task {
            let userStatus = await interactor.fetchStatus() ?? .notStarted
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.didReceive(status: userStatus)
            }
        }
    }

    func didTapHide() {
        interactor.hideCard()
    }
}

// MARK: - SoraCardInfoBoardInteractorOutput

extension SoraCardInfoBoardPresenter: SoraCardInfoBoardInteractorOutput {
    func didReceive(status: SCKYCUserStatus) {
        view?.didStopLoading()

        let statusViewModel = viewModelFactory.buildViewModel(from: status)
        view?.didReceive(stateViewModel: statusViewModel)
    }

    func didReceive(hiddenState: Bool) {
        moduleOutput?.didChanged(soraCardHiddenState: hiddenState)
    }

    func didReceive(kycStatuses: [SCKYCStatusResponse]) {
        if kycStatuses.isEmpty {
            router.start(from: view, data: SCKYCUserDataModel(), wallet: wallet)
        } else {
            router.showVerificationStatus(from: view)
        }
    }

    func didReceive(error: NetworkingError) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func restartKYC() {
        router.start(from: view, data: SCKYCUserDataModel(), wallet: wallet)
    }
}

// MARK: - Localizable

extension SoraCardInfoBoardPresenter: Localizable {
    func applyLocalization() {}
}

extension SoraCardInfoBoardPresenter: SoraCardInfoBoardModuleInput {
    func add(moduleOutput: SoraCardInfoBoardModuleOutput?) {
        self.moduleOutput = moduleOutput
    }
}
