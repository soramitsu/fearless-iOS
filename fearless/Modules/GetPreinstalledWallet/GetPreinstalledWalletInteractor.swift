import UIKit
import RobinHood

final class GetPreinstalledWalletInteractor: BaseAccountImportInteractor {
    // MARK: - Private properties

    private weak var output: GetPreinstalledWalletInteractorOutput?
    private let qrDecoder: QRDecoderProtocol
    private let qrExtractionService: QRExtractionServiceProtocol
    private let qrScanService: QRCaptureServiceProtocol
    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol

    init(
        qrDecoder: QRDecoderProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        qrScanService: QRCaptureServiceProtocol,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        defaultSource: AccountImportSource,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.qrDecoder = qrDecoder
        self.qrExtractionService = qrExtractionService
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
        let matcher = QRScanMatcher(decoder: qrDecoder)

        qrExtractionService.extract(
            from: image,
            using: [matcher],
            dispatchCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                if let addressInfo = matcher.qrInfo {
                    self?.output?.handleMatched(addressInfo: addressInfo)
                }
            case let .failure(error):
                if case let QRExtractionServiceError.plainAddress(address) = error {
                    self?.output?.handleAddress(address)
                    return
                }

                self?.output?.handleQRService(error: error)
            }
        }
    }

    func startScanning() {
        qrScanService.start()
    }

    func stopScanning() {
        qrScanService.stop()
    }
}
