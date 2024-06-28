import UIKit
import SSFQRService
import RobinHood

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
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let updatedWallet = accountItem.replacingIsBackuped(true)
            self?.settings.save(value: updatedWallet)

            return updatedWallet
        }

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    do {
                        let accountItem = try importOperation
                            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        self?.settings.setup()
                        self?.output?.didCompleteAccountImport()
                        self?.eventCenter.notify(with: SelectedAccountChanged(account: accountItem))
                    } catch {
                        self?.output?.didReceiveAccountImport(error: error)
                    }

                case let .failure(error):
                    self?.output?.didReceiveAccountImport(error: error)

                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.output?.didReceiveAccountImport(error: error)
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
            guard let preinstalledWallet = matcher.preinstalledWallet else {
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
