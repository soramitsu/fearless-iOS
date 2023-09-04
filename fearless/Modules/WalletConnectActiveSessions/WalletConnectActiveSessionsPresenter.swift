import Foundation
import WalletConnectSign
import SoraFoundation

protocol WalletConnectActiveSessionsViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(viewModels: [WalletConnectActiveSessionsViewModel])
}

protocol WalletConnectActiveSessionsInteractorInput: AnyObject {
    func setup(with output: WalletConnectActiveSessionsInteractorOutput)
}

final class WalletConnectActiveSessionsPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectActiveSessionsViewInput?
    private let router: WalletConnectActiveSessionsRouterInput
    private let interactor: WalletConnectActiveSessionsInteractorInput

    private let viewModelFactory: WalletConnectActiveSessionsViewModelFactory

    private var sessions: [Session]?

    // MARK: - Constructors

    init(
        viewModelFactory: WalletConnectActiveSessionsViewModelFactory,
        interactor: WalletConnectActiveSessionsInteractorInput,
        router: WalletConnectActiveSessionsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard let sessions = sessions else {
            return
        }
        let viewModels = viewModelFactory.createViewModel(from: sessions)
        view?.didReceive(viewModels: viewModels)
        view?.didStopLoading()
    }
}

// MARK: - WalletConnectActiveSessionsViewOutput

extension WalletConnectActiveSessionsPresenter: WalletConnectActiveSessionsViewOutput {
    func didLoad(view: WalletConnectActiveSessionsViewInput) {
        self.view = view
        view.didStartLoading()
        interactor.setup(with: self)
    }
}

// MARK: - WalletConnectActiveSessionsInteractorOutput

extension WalletConnectActiveSessionsPresenter: WalletConnectActiveSessionsInteractorOutput {
    func didReceive(sessions: [WalletConnectSign.Session]) {
        self.sessions = sessions
        provideViewModel()
    }
}

// MARK: - Localizable

extension WalletConnectActiveSessionsPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletConnectActiveSessionsPresenter: WalletConnectActiveSessionsModuleInput {}
