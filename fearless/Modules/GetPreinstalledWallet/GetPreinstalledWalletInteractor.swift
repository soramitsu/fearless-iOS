import RobinHood
import SSFQRService
import UIKit

final class GetPreinstalledWalletInteractor: BaseAccountImportInteractor {
    // MARK: - Private properties

    private weak var output: GetPreinstalledWalletInteractorOutput?
    private let qrService: QRService
    private let qrScanService: QRCaptureServiceProtocol
    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol

    init(
        qrService: QRService,
        qrScanService: QRCaptureServiceProtocol,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        defaultSource: AccountImportSource,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.qrService = qrService
        self.qrScanService = qrScanService
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: operationManager,
            keystoreImportService: keystoreImportService,
            defaultSource: defaultSource
        )
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return accountItem.replacingIsBackuped(true)
        }

        saveOperation.completionBlock = { [weak self] in
            let result = saveOperation.result
            saveOperation.completionBlock = nil
            DispatchQueue.main.async {
                guard let self else {
                    ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    return
                }
                switch result {
                case let .success(accountItem):
                    self.settings.save(value: accountItem, runningCompletionIn: .main) { [weak self] result in
                        switch result {
                        case let .success(savedAccount):
                            (importOperation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
                            self?.output?.didCompleteAccountImport()
                            self?.eventCenter.notify(with: SelectedAccountChanged(account: savedAccount))
                        case let .failure(error):
                            let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                            self?.output?.didReceiveAccountImport(error: failure)
                        }
                    }
                case let .failure(error):
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                    self.output?.didReceiveAccountImport(error: failure)
                case .none:
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    self.output?.didReceiveAccountImport(error: failure)
                }
            }
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }
}

// MARK: - GetPreinstalledWalletInteractorInput

extension GetPreinstalledWalletInteractor: GetPreinstalledWalletInteractorInput {
    func setup(with output: GetPreinstalledWalletInteractorOutput) {
        self.output = output
        qrScanService.delegate = output
    }

    func extractQr(from image: UIImage) {
        do {
            let matcher = try qrService.extractQrCode(from: image)
            guard let preinstalledWallet = matcher.address else {
                throw ConvenienceError(error: "Matches has't preinstalled wallet")
            }
            output?.handleAddress(preinstalledWallet)
        } catch {
            output?.handleQRService(error: error)
        }
    }

    func startScanning() {
        qrScanService.start()
    }

    func stopScanning() {
        qrScanService.stop()
    }
}
