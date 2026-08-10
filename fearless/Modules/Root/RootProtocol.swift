import UIKit

protocol RootViewProtocol: ControllerBackedProtocol {
    func didReceive(state: RootViewState)
}

protocol RootPresenterProtocol: AnyObject {
    func loadOnLaunch()
    func reload()
}

protocol RootWireframeProtocol: AnyObject {
    func showSplash(splashView: ControllerBackedProtocol?, on window: UIWindow)
    func showLocalAuthentication(on window: UIWindow)
    func showMain(on window: UIWindow)
    func showPincodeSetup(on window: UIWindow)
    func showBroken(on window: UIWindow)
    func showOnboarding(on window: UIWindow, with config: OnboardingConfigWrapper)
}

protocol RootInteractorInputProtocol: AnyObject {
    func setup(runMigrations: Bool)
    func fetchOnboardingConfig() async throws -> OnboardingConfigWrapper?
}

enum RootSetupPhase: String, Equatable {
    case languageMigration
    case userStorageMigration
    case substrateMigration
    case substratePreflight
    case selectedWalletOpening
}

enum RootSetupIncidentCode: String, Equatable {
    case languageMigrationFailed = "LANGUAGE_MIGRATION_FAILED"
    case userStorageMigrationFailed = "USER_STORAGE_MIGRATION_FAILED"
    case userStorageCompatibilityMissing = "USER_STORAGE_COMPATIBILITY_MISSING"
    case userStorageIntegrityRejected = "USER_STORAGE_INTEGRITY_REJECTED"
    case substrateMigrationFailed = "SUBSTRATE_MIGRATION_FAILED"
    case substrateCompatibilityMissing = "SUBSTRATE_COMPATIBILITY_MISSING"
    case substrateIntegrityRejected = "SUBSTRATE_INTEGRITY_REJECTED"
    case substratePreflightFailed = "SUBSTRATE_PREFLIGHT_FAILED"
    case substratePreflightCompatibilityMissing = "SUBSTRATE_PREFLIGHT_COMPATIBILITY_MISSING"
    case selectedWalletOpeningFailed = "SELECTED_WALLET_OPENING_FAILED"
    case walletMappingConflict = "WALLET_MAPPING_CONFLICT"
    case walletRecordRejected = "WALLET_RECORD_REJECTED"
    case insufficientStorage = "INSUFFICIENT_STORAGE"
}

enum RootSetupRecoveryAction: Equatable {
    case retry
    case installLatestBuild
    case freeStorage(requiredByteCount: UInt64)
}

struct RootSetupFailure: Equatable {
    let phase: RootSetupPhase
    let incidentCode: RootSetupIncidentCode
    let elapsedTime: TimeInterval
    let recoveryAction: RootSetupRecoveryAction
}

enum RootSetupState: Equatable {
    case running(RootSetupPhase)
    case slow(RootSetupPhase, elapsedTime: TimeInterval)
    case ready
    case failed(RootSetupFailure)
}

protocol RootInteractorOutputProtocol: AnyObject {
    func didUpdateSetup(_ state: RootSetupState)
    func didFailSetup(_ failure: RootSetupFailure)
}

protocol RootPresenterFactoryProtocol: AnyObject {
    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol
}
