import UIKit
import RobinHood
import IrohaCrypto

enum AccountExportPasswordInteractorError: Error {
    case missingAccount
    case invalidResult
    case unsupportedAddress
}

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!

    let exportJsonWrapper: KeystoreExportWrapperProtocol
    let repository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol

    init(exportJsonWrapper: KeystoreExportWrapperProtocol,
         repository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol) {
        self.exportJsonWrapper = exportJsonWrapper
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension AccountExportPasswordInteractor: AccountExportPasswordInteractorInputProtocol {
    func exportAccount(address: String, password: String) {
        let accountOperation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        let exportOperation: BaseOperation<RestoreJson> = ClosureOperation { [weak self] in
            guard let account = try accountOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw AccountExportPasswordInteractorError.missingAccount
            }

            guard let data = try self?.exportJsonWrapper
                    .export(account: account, password: password) else {
                throw BaseOperationError.parentOperationCancelled
            }

            guard let result = String(data: data, encoding: .utf8) else {
                throw AccountExportPasswordInteractorError.invalidResult
            }

            let addressRawType = try SS58AddressFactory().type(fromAddress: address)

            guard let chain = SNAddressType(rawValue: addressRawType.uint8Value)?.chain else {
                throw AccountExportPasswordInteractorError.unsupportedAddress
            }

            return RestoreJson(data: result,
                               chain: chain,
                               cryptoType: account.cryptoType)
        }

        exportOperation.addDependency(accountOperation)

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didExport(json: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [accountOperation, exportOperation], in: .transient)
    }
}
