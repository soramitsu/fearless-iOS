import UIKit
import RobinHood
import IrohaCrypto

enum AccountExportPasswordInteractorError: Error {
    case missingAccount
    case invalidResult
    case unsupportedAddress
    case unsupportedCryptoType
    case missingGenesisHash
}

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!

    private let exportJsonWrapper: KeystoreExportWrapperProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol
    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol

    init(
        exportJsonWrapper: KeystoreExportWrapperProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    ) {
        self.exportJsonWrapper = exportJsonWrapper
        self.repository = repository
        self.operationManager = operationManager
        self.extrinsicOperationFactory = extrinsicOperationFactory
    }
}

extension AccountExportPasswordInteractor: AccountExportPasswordInteractorInputProtocol {
    func exportAccount(address: String, password: String, chain: ChainModel) {
        fetchChainAccount(
            chain: chain,
            address: address,
            from: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self,
                      let response = chainResponse,
                      let metaAccount = SelectedWalletSettings.shared.value else {
                    self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
                    return
                }

                let genesisOperation = self.extrinsicOperationFactory.createGenesisBlockHashOperation()
                genesisOperation.completionBlock = { [weak self] in
                    do {
                        guard let genesisHash = try genesisOperation.extractResultData() else {
                            throw AccountExportPasswordInteractorError.missingGenesisHash
                        }
                        self?.createExportOperation(
                            address: address,
                            password: password,
                            chain: chain,
                            chainAccount: response,
                            metaId: metaAccount.metaId,
                            genesisHash: genesisHash
                        )
                    } catch {
                        self?.presenter.didReceive(error: error)
                    }
                }
                self.operationManager.enqueue(operations: [genesisOperation], in: .transient)
            case .failure:
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            }
        }
    }

    private func createExportOperation(
        address: String,
        password: String,
        chain: ChainModel,
        chainAccount: ChainAccountResponse,
        metaId: String,
        genesisHash: String
    ) {
        let exportOperation: BaseOperation<RestoreJson> = ClosureOperation { [weak self] in
            guard let data = try self?.exportJsonWrapper.export(
                chainAccount: chainAccount,
                password: password,
                address: address,
                metaId: metaId,
                accountId: chainAccount.isChainAccount ? chainAccount.accountId : nil,
                genesisHash: genesisHash
            )
            else {
                throw BaseOperationError.parentOperationCancelled
            }

            guard let result = String(data: data, encoding: .utf8) else {
                throw AccountExportPasswordInteractorError.invalidResult
            }

            return RestoreJson(
                data: result,
                chain: chain,
                cryptoType: chainAccount.cryptoType
            )
        }

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

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}

extension AccountExportPasswordInteractor: AccountFetching {}
