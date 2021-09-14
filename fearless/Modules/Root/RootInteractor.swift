import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    let settings: SelectedWalletSettings
    let keystore: KeystoreProtocol
    let applicationConfig: ApplicationConfigProtocol
    let eventCenter: EventCenterProtocol
    let migrators: [Migrating]
    let logger: LoggerProtocol?

    init(
        settings: SelectedWalletSettings,
        keystore: KeystoreProtocol,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil
    ) {
        self.settings = settings
        self.keystore = keystore
        self.applicationConfig = applicationConfig
        self.eventCenter = eventCenter
        self.migrators = migrators
        self.logger = logger
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
        do {
            if !settings.hasValue {
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)

                presenter?.didDecideOnboarding()
                return
            }

            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }

    func setup() {
        setupURLHandlingService()
        runMigrators()

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
