import Foundation
import WalletConnectSign
import SoraKeystore
import CommonWallet
import SSFUtils
import SoraFoundation

final class MainTabBarInteractor {
    private weak var presenter: MainTabBarInteractorOutputProtocol?

    private let eventCenter: EventCenterProtocol
    private let keystoreImportService: KeystoreImportServiceProtocol
    private let serviceCoordinator: ServiceCoordinatorProtocol
    private let walletConnect: WalletConnectService

    deinit {
        stopServices()
    }

    init(
        eventCenter: EventCenterProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        walletConnect: WalletConnectService
    ) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator
        self.walletConnect = walletConnect

        startServices()
    }

    private func startServices() {
        serviceCoordinator.setup()
    }

    private func stopServices() {
        serviceCoordinator.throttle()
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup(with output: MainTabBarInteractorOutputProtocol) {
        presenter = output

        eventCenter.add(observer: self, dispatchIn: nil)
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didRequestImportAccount()
        }

        walletConnect.set(delegate: self)
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        serviceCoordinator.updateOnAccountChange()
        DispatchQueue.main.async {
            self.presenter?.didReloadSelectedAccount()
        }
    }
}

extension MainTabBarInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        guard keystoreImportService.definition != nil else {
            return
        }

        presenter?.didRequestImportAccount()
    }
}

// MARK: - WalletConnectServiceDelegate

extension MainTabBarInteractor: WalletConnectServiceDelegate {
    func sign(request: Request, session: Session?) {
        presenter?.didReceive(request: request, session: session)
    }

    func session(proposal: Session.Proposal) {
        presenter?.didReceive(proposal: proposal)
    }
}
