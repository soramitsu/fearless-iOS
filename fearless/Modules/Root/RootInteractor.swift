import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood
import SoraFoundation

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    private let settings: SelectedWalletSettings
    private let applicationConfig: ApplicationConfigProtocol
    private let eventCenter: EventCenterProtocol
    private let migrators: [Migrating]
    private let logger: LoggerProtocol?
    private let startViewHelper: StartViewHelperProtocol

    init(
        settings: SelectedWalletSettings,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil,
        startViewHelper: StartViewHelperProtocol
    ) {
        self.settings = settings
        self.applicationConfig = applicationConfig
        self.eventCenter = eventCenter
        self.migrators = migrators
        self.logger = logger
        self.startViewHelper = startViewHelper
    }

    private func setupURLHandlingService() {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let callbackUrl = applicationConfig.purchaseRedirect
        let purchaseHandler = PurchaseCompletionHandler(
            callbackUrl: callbackUrl,
            eventCenter: eventCenter
        )

        URLHandlingService.shared.setup(children: [purchaseHandler, keystoreImportService])
    }

    private func runMigrators() {
        migrators.forEach { migrator in
            do {
                try migrator.migrate()
            } catch {
                logger?.error(error.localizedDescription)
            }
        }
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        let startView = startViewHelper.startView()
        switch startView {
        case .pin:
            presenter?.didDecideLocalAuthentication()
        case .pinSetup:
            presenter?.didDecidePincodeSetup()
        case .login:
            presenter?.didDecideOnboarding()
        case .broken:
            presenter?.didDecideBroken()
        }
    }

    func setup(runMigrations: Bool) {
        setupURLHandlingService()

        if runMigrations {
            runMigrators()
        }

        // TODO: Move to loading screen
        settings.setup(runningCompletionIn: .main) { result in
            switch result {
            case let .success(maybeMetaAccount):
                if let metaAccount = maybeMetaAccount {
                    self.logger?.debug("Selected account: \(metaAccount.metaId)")
                } else {
                    self.logger?.debug("No selected account")
                }
            case let .failure(error):
                self.logger?.error("Selected account setup failed: \(error)")
            }
        }
    }
}
