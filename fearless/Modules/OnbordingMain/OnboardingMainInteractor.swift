import Foundation
import SSFUtils
import SSFCloudStorage

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    private let keystoreImportService: KeystoreImportServiceProtocol
    private let cloudStorage: FearlessCompatibilityProtocol

    init(
        keystoreImportService: KeystoreImportServiceProtocol,
        cloudStorage: FearlessCompatibilityProtocol
    ) {
        self.keystoreImportService = keystoreImportService
        self.cloudStorage = cloudStorage
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
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
