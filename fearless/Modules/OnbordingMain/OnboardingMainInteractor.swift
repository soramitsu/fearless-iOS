import Foundation
import SSFAccountManagment
import SSFUtils
import SSFCloudStorage
import TonSwift
import RobinHood
import SSFModels

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    private let keystoreImportService: KeystoreImportServiceProtocol
    private let cloudStorage: CloudStorageServiceProtocol
    private let featureToggleService: FeatureToggleProviderProtocol
    private let operationQueue: OperationQueue
    private let accountOperationFactory: MetaAccountOperationFactoryProtocol
    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol

    init(
        keystoreImportService: KeystoreImportServiceProtocol,
        cloudStorage: CloudStorageServiceProtocol,
        featureToggleService: FeatureToggleProviderProtocol,
        operationQueue: OperationQueue,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.keystoreImportService = keystoreImportService
        self.cloudStorage = cloudStorage
        self.featureToggleService = featureToggleService
        self.operationQueue = operationQueue
        self.accountOperationFactory = accountOperationFactory
        self.settings = settings
        self.eventCenter = eventCenter
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
    
    private func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            self?.settings.save(value: accountItem)

            return accountItem
        }

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    do {
                        let accountItem = try importOperation
                            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                        self?.settings.setup()
                        self?.eventCenter.notify(with: SelectedAccountChanged(account: accountItem))
                        self?.presenter?.didCompleteConfirmation()
                    } catch {
                        self?.presenter?.didReceive(error: error)
                    }
                case let .failure(error):
                    self?.presenter?.didReceive(error: error)

                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        saveOperation.addDependency(importOperation)
        operationQueue.addOperations([importOperation, saveOperation], waitUntilFinished: false)
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
                let accounts = try await cloudStorage.getBackupAccounts()
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
    
    func createTonAccount() {
        let allWords = TonSwift.Mnemonic.mnemonicNew(wordsCount: 24)
        let request = MetaAccountImportTonMnemonicRequest(
            mnemonic: allWords.joined(separator: " "),
            username: "Wallet"
        )
        let operation = accountOperationFactory.newTonMetaAccountOperation(
            request: request,
            isBackedUp: false
        )
        createAccountUsingOperation(operation)
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}
