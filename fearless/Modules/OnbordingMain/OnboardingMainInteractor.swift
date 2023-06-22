import Foundation
import SSFUtils
import SSFCloudStorage

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    private let keystoreImportService: KeystoreImportServiceProtocol
    private let cloudStorage: CloudStorageServiceProtocol

    init(
        keystoreImportService: KeystoreImportServiceProtocol,
        cloudStorage: CloudStorageServiceProtocol
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
        cloudStorage.getBackupAccounts { [weak self] result in
            self?.presenter?.didReceiveBackupAccounts(result: result)
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
