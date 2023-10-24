import Foundation
import SSFUtils
import SSFCloudStorage

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    private let keystoreImportService: KeystoreImportServiceProtocol
    private let cloudStorage: FearlessCompatibilityProtocol
    private let featureToggleService: FeatureToggleProviderProtocol
    private let operationQueue: OperationQueue

    init(
        keystoreImportService: KeystoreImportServiceProtocol,
        cloudStorage: FearlessCompatibilityProtocol,
        featureToggleService: FeatureToggleProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.keystoreImportService = keystoreImportService
        self.cloudStorage = cloudStorage
        self.featureToggleService = featureToggleService
        self.operationQueue = operationQueue
    }

    deinit {
        cloudStorage.disconnect()
    }

    private func fetchFeatureToggleConfig() {
        let fetchOperation = featureToggleService.fetchConfigOperation()

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.presenter?.didReceiveFeatureToggleConfig(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }

        fetchFeatureToggleConfig()
    }

    func activateGoogleBackup() {
        Task {
            do {
                cloudStorage.disconnect()
                let accounts = try await cloudStorage.getFearlessBackupAccounts()
                await MainActor.run {
                    presenter?.didReceiveBackupAccounts(result: .success(accounts))
                }
            } catch {
                cloudStorage.disconnect()
                await MainActor.run {
                    presenter?.didReceiveBackupAccounts(result: .failure(error))
                }
            }
        }
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}
