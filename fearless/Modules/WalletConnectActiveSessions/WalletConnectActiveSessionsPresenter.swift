import Foundation
import WalletConnectSign
import SoraFoundation
import SSFQRService
import SSFModels

protocol WalletConnectActiveSessionsViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(viewModels: [WalletConnectActiveSessionsViewModel])
}

protocol WalletConnectActiveSessionsInteractorInput: AnyObject {
    func setup(with output: WalletConnectActiveSessionsInteractorOutput)
    func setupConnection(uri: String) async throws
    func getSesstion()
}

final class WalletConnectActiveSessionsPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectActiveSessionsViewInput?
    private let router: WalletConnectActiveSessionsRouterInput
    private let interactor: WalletConnectActiveSessionsInteractorInput

    private let wallet: MetaAccountModel
    private let viewModelFactory: WalletConnectActiveSessionsViewModelFactory

    private var sessions: [Session]?
    private var tonApps: [TonConnectApp]?

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        viewModelFactory: WalletConnectActiveSessionsViewModelFactory,
        interactor: WalletConnectActiveSessionsInteractorInput,
        router: WalletConnectActiveSessionsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModels: [WalletConnectActiveSessionsViewModel]
        switch wallet.ecosystem {
        case .regular:
            guard let sessions = sessions else {
                return
            }
            viewModels = viewModelFactory.createViewModel(from: sessions)
        case .ton:
            guard let tonApps = tonApps else {
                return
            }
            viewModels = viewModelFactory.createViewModel(from: tonApps)
        }
        Task { @MainActor in
            view?.didReceive(viewModels: viewModels)
            view?.didStopLoading()
        }
    }
    
    private func filterSession( by text: String?) {
        let sessions = sessions?.filter {
            guard let text = text else { return false }
            if text.isEmpty {
                return true
            }
            return $0.peer.name.lowercased().contains(text.lowercased()) == true
        }
        guard let sessions = sessions else { return }
        let viewModels = viewModelFactory.createViewModel(from: sessions)
        view?.didReceive(viewModels: viewModels)
    }
    
    private func filterTonApp( by text: String?) {
        let tonApps = tonApps?.filter {
            guard let text = text else { return false }
            if text.isEmpty {
                return true
            }
            return $0.name.lowercased().contains(text.lowercased()) == true
        }
        guard let tonApps = tonApps else { return }
        let viewModels = viewModelFactory.createViewModel(from: tonApps)
        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: - WalletConnectActiveSessionsViewOutput

extension WalletConnectActiveSessionsPresenter: WalletConnectActiveSessionsViewOutput {
    func createNewConnection() {
        router.showScaner(output: self, view: view)
    }

    func filterConnection(by text: String?) {
        switch wallet.ecosystem {
        case .regular:
            filterSession(by: text)
        case .ton:
            filterTonApp(by: text)
        }
    }

    func didSelectRowAt(_ indexPath: IndexPath) {
        switch wallet.ecosystem {
        case .regular:
            guard let session = sessions?[safe: indexPath.row] else {
                return
            }
            router.showSession(.walletConnect(session), view: view)
        case .ton:
            guard let app = tonApps?[safe: indexPath.row] else {
                return
            }
            router.showSession(.tonConnect(app: app, delegate: self), view: view)
        }
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func didLoad(view: WalletConnectActiveSessionsViewInput) {
        self.view = view
        view.didStartLoading()
        interactor.setup(with: self)
    }
}

// MARK: - WalletConnectActiveSessionsInteractorOutput

extension WalletConnectActiveSessionsPresenter: WalletConnectActiveSessionsInteractorOutput {
    func didReceive(connectedApps: [TonConnectApp]) {
        tonApps = connectedApps.filter { $0.connectionType == .http }
        provideViewModel()
    }
    
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

// MARK: - ScanQRModuleOutput

extension WalletConnectActiveSessionsPresenter: ScanQRModuleOutput {
    func didFinishWith(scanType: QRMatcherType) {
        guard let uri = scanType.uri else {
            return
        }
        Task {
            do {
                try await interactor.setupConnection(uri: uri)
            } catch {
                _ = await MainActor.run(body: {
                    router.present(error: error, from: view, locale: selectedLocale)
                })
            }
        }
    }
}

extension Session: WalletConnectActiveSessionsItem {
    var name: String {
        peer.name
    }
    
    var url: URL? {
        URL(string: peer.url)
    }
    
    var icon: URL? {
        guard let icon = peer.icons.first else {
            return nil
        }
        return URL(string: icon)
    }
}

extension WalletConnectActiveSessionsPresenter: WalletConnectProposalModuleOutput {
    func disconnected() {
        interactor.getSesstion()
    }
}
