import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

enum ExportSeedInteractorError: Error {
    case missingSeed
}

final class ExportSeedInteractor {
    weak var presenter: ExportSeedInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let repository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol

    init(keystore: KeystoreProtocol,
         repository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol) {
        self.keystore = keystore
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension ExportSeedInteractor: ExportSeedInteractorInputProtocol {
    func fetchExportDataForAddress(_ address: String) {
        let accountOperation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        let exportOperation: BaseOperation<ExportSeedData> = ClosureOperation { [weak self] in
            guard let account = try accountOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw ExportMnemonicInteractorError.missingAccount
            }

            var optionalSeed: Data? = try self?.keystore.fetchSeedForAddress(address)

            if optionalSeed == nil && account.cryptoType.supportsSeedFromSecretKey {
                optionalSeed = try self?.keystore.fetchSecretKeyForAddress(address)
            }

            guard let seed = optionalSeed else {
                throw ExportSeedInteractorError.missingSeed
            }

            let derivationPath: String? = try self?.keystore.fetchDeriviationForAddress(address)

            let addressRawType = try SS58AddressFactory().type(fromAddress: address)

            guard let chain = SNAddressType(rawValue: addressRawType.uint8Value)?.chain else {
                throw AccountExportPasswordInteractorError.unsupportedAddress
            }

            return ExportSeedData(account: account,
                                  seed: seed,
                                  derivationPath: derivationPath,
                                  networkType: chain)
        }

        exportOperation.addDependency(accountOperation)

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didReceive(exportData: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [accountOperation, exportOperation], in: .transient)
    }
}
