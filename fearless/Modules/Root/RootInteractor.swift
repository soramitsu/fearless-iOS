import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood
import SoraFoundation

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    private let chainRegistry: ChainRegistryProtocol
    private let settings: SelectedWalletSettings
    private let applicationConfig: ApplicationConfigProtocol
    private let eventCenter: EventCenterProtocol
    private let migrators: [Migrating]
    private let logger: LoggerProtocol?
    private let onboardingService: OnboardingServiceProtocol
    private let onboardingConfigResolver: OnboardingConfigVersionResolver

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SelectedWalletSettings,
        applicationConfig: ApplicationConfigProtocol,
        eventCenter: EventCenterProtocol,
        migrators: [Migrating],
        logger: LoggerProtocol? = nil,
        onboardingService: OnboardingServiceProtocol,
        onboardingConfigResolver: OnboardingConfigVersionResolver
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.applicationConfig = applicationConfig
        self.eventCenter = eventCenter
        self.migrators = migrators
        self.logger = logger
        self.onboardingService = onboardingService
        self.onboardingConfigResolver = onboardingConfigResolver
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
    func setup(runMigrations: Bool) {
        setupURLHandlingService()

        settings.setup(runningCompletionIn: .global()) { result in
            if runMigrations {
                self.runMigrators()
            }

            switch result {
            case let .success(wallet):
                if let wallet = wallet {
                    self.chainRegistry.performHotBoot()
                    self.chainRegistry.subscribeToChians()
                    self.logger?.debug("Selected account: \(wallet.metaId)")
                } else {
                    self.chainRegistry.performColdBoot()
                    self.logger?.debug("No selected account")
                }
            case let .failure(error):
                self.logger?.error("Selected account setup failed: \(error)")
            }
        }
    }

    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper? {
        do {
            let onboardingConfigPlatform = try await onboardingService.fetchConfigs()
            let onboardingWrappers = onboardingConfigPlatform.ios
            return onboardingConfigResolver.resolve(configWrappers: onboardingWrappers)
        } catch {
            throw error
        }
    }
}
