import Foundation
import SoraKeystore
import CommonWallet
import FearlessUtils
import SoraFoundation

final class MainTabBarInteractor {
    private weak var presenter: MainTabBarInteractorOutputProtocol?

    private let eventCenter: EventCenterProtocol
    private let keystoreImportService: KeystoreImportServiceProtocol
    private let serviceCoordinator: ServiceCoordinatorProtocol
    private let applicationHandler: ApplicationHandlerProtocol

    private var goneBackgroundTimestamp: TimeInterval?

    deinit {
        stopServices()
    }

    init(
        eventCenter: EventCenterProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator
        self.applicationHandler = applicationHandler

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

        applicationHandler.delegate = self
        eventCenter.add(observer: self, dispatchIn: .main)
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didRequestImportAccount()
        }
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        serviceCoordinator.updateOnAccountChange()
        presenter?.didReloadSelectedAccount()
    }

    func processBalanceChanged(event _: WalletBalanceChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processStakingChanged(event _: WalletStakingInfoChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processNewTransaction(event _: WalletNewTransactionInserted) {
        presenter?.didUpdateWalletInfo()
    }

    func processUserInactive(event _: UserInactiveEvent) {
        presenter?.handleLongInactivity()
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

extension MainTabBarInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        goneBackgroundTimestamp = Date().timeIntervalSince1970
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        if let goneBackgroundTimestamp = goneBackgroundTimestamp,
           Date().timeIntervalSince1970 - goneBackgroundTimestamp > UtilityConstants.inactiveSessionDropTimeInSeconds {
            presenter?.handleLongInactivity()
        }
    }
}
