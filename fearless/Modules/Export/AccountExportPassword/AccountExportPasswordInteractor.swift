import UIKit
import RobinHood
import IrohaCrypto
import SSFModels

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
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol?

    init(
        exportJsonWrapper: KeystoreExportWrapperProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol?,
        chainRepository: AnyDataProviderRepository<ChainModel>
    ) {
        self.exportJsonWrapper = exportJsonWrapper
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.chainRepository = chainRepository
    }
}

extension AccountExportPasswordInteractor: AccountExportPasswordInteractorInputProtocol {
    func exportWallet(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        password: String
    ) {
        var jsons: [RestoreJson] = []

        for chainAccount in accounts {
            if let data = try? exportJsonWrapper.export(
                chainAccount: chainAccount.account,
                password: password,
                address: AddressFactory.address(for: chainAccount.account.accountId, chain: chainAccount.chain),
                metaId: wallet.metaId,
                accountId: chainAccount.account.isChainAccount ? chainAccount.account.accountId : nil,
                genesisHash: nil
            ), let result = String(data: data, encoding: .utf8) {
                do {
                    let fileUrl = try URL(fileURLWithPath: NSTemporaryDirectory() + "/\(AddressFactory.address(for: chainAccount.account.accountId, chain: chainAccount.chain)).json")
                    try result.write(toFile: fileUrl.path, atomically: true, encoding: .utf8)
                    let json = RestoreJson(
                        data: result,
                        chain: chainAccount.chain,
                        cryptoType: nil,
                        fileURL: fileUrl
                    )

                    jsons.append(json)
                } catch {}
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.presenter.didExport(jsons: jsons)
        }
    }

    func exportAccount(address: String, password: String, chain: ChainModel, wallet: MetaAccountModel) {
        fetchChainAccountFor(
            meta: wallet,
            chain: chain,
            address: address
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self,
                      let response = chainResponse else {
                    self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
                    return
                }

                if let genesisOperation = self.extrinsicOperationFactory?.createGenesisBlockHashOperation() {
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
                                metaId: wallet.metaId,
                                genesisHash: genesisHash
                            )
                        } catch {
                            DispatchQueue.main.async {
                                self?.presenter.didReceive(error: error)
                            }
                        }
                    }
                    genesisOperation.qualityOfService = .userInitiated
                    self.operationManager.enqueue(operations: [genesisOperation], in: .transient)
                } else {
                    self.createExportOperation(
                        address: address,
                        password: password,
                        chain: chain,
                        chainAccount: response,
                        metaId: wallet.metaId,
                        genesisHash: nil
                    )
                }
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
        genesisHash: String?
    ) {
        let exportOperation: BaseOperation<String> = ClosureOperation { [weak self] in
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

            return result
        }

        let fileSaveOperation: BaseOperation<RestoreJson> = ClosureOperation {
            let content = try exportOperation.extractNoCancellableResultData()
            let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "/\(address).json")
            try content.write(toFile: fileUrl.path, atomically: true, encoding: .utf8)
            return RestoreJson(
                data: content,
                chain: chain,
                cryptoType: chainAccount.cryptoType,
                fileURL: fileUrl
            )
        }

        fileSaveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try fileSaveOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didExport(jsons: [model])
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        fileSaveOperation.addDependency(exportOperation)

        exportOperation.qualityOfService = .userInitiated
        fileSaveOperation.qualityOfService = .userInitiated
        operationManager.enqueue(operations: [exportOperation, fileSaveOperation], in: .transient)
    }
}

extension AccountExportPasswordInteractor: AccountFetching {}
