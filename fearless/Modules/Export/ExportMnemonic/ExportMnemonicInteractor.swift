import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

enum ExportMnemonicInteractorError: Error {
    case missingAccount
    case missingEntropy
}

final class ExportMnemonicInteractor {
    weak var presenter: ExportMnemonicInteractorOutputProtocol!

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

extension ExportMnemonicInteractor: ExportMnemonicInteractorInputProtocol {
    func fetchExportDataForAddress(_ address: String) {
        let accountOperation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        let exportOperation: BaseOperation<ExportMnemonicData> = ClosureOperation { [weak self] in
            guard let account = try accountOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw ExportMnemonicInteractorError.missingAccount
            }

            guard let entropy = try self?.keystore.fetchEntropyForAddress(address) else {
                throw ExportMnemonicInteractorError.missingEntropy
            }

            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)

            let derivationPath: String? = try self?.keystore.fetchDeriviationForAddress(address)

            let addressRawType = try SS58AddressFactory().type(fromAddress: address)

            guard let chain = SNAddressType(rawValue: addressRawType.uint8Value)?.chain else {
                throw AccountExportPasswordInteractorError.unsupportedAddress
            }

            return ExportMnemonicData(account: account,
                                      mnemonic: mnemonic,
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
