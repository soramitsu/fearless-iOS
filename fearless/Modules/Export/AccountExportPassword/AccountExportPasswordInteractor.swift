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

/// Keeps successful recovery files available without treating an incomplete batch as a complete backup.
struct AccountExportBatchError: LocalizedError {
    let available: [RestoreJson]
    let unavailable: [ChainAccountInfo]

    var errorDescription: String? { "Some accounts could not be exported." }
}

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!

    private let exportDirectory: URL
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
        chainRepository: AnyDataProviderRepository<ChainModel>,
        exportDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.exportDirectory = exportDirectory
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
        var unavailable: [ChainAccountInfo] = []

        for chainAccount in accounts {
            do {
                let address = try AddressFactory.address(for: chainAccount.account.accountId, chain: chainAccount.chain)
                let data = try exportJsonWrapper.export(
                    chainAccount: chainAccount.account,
                    password: password,
                    address: address,
                    metaId: wallet.metaId,
                    accountId: chainAccount.account.isChainAccount ? chainAccount.account.accountId : nil,
                    genesisHash: nil
                )
                guard let result = String(data: data, encoding: .utf8) else {
                    throw AccountExportPasswordInteractorError.invalidResult
                }
                let fileURL = try saveExportedFile(result, address: address)
                jsons.append(RestoreJson(
                    data: result, chain: chainAccount.chain, cryptoType: chainAccount.account.cryptoType,
                    fileURL: fileURL, accountId: chainAccount.account.accountId
                ))
            } catch {
                unavailable.append(chainAccount)
            }
        }

        DispatchQueue.main.async { [weak self] in
            if !unavailable.isEmpty {
                self?.presenter.didReceive(error: AccountExportBatchError(available: jsons, unavailable: unavailable))
            } else if jsons.isEmpty {
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            } else {
                self?.presenter.didExport(jsons: jsons)
            }
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
                                chainAccountInfo: ChainAccountInfo(chain: chain, account: response),
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
                        chainAccountInfo: ChainAccountInfo(chain: chain, account: response),
                        metaId: wallet.metaId,
                        genesisHash: nil
                    )
                }
            case .failure:
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            }
        }
    }

    private func saveExportedFile(_ content: String, address: String) throws -> URL {
        // A share sheet can outlive a later export attempt. Each model owns its
        // bytes even when another chain or password produces the same filename.
        let directory = exportDirectory.appendingPathComponent("fearless-json-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let file = directory.appendingPathComponent(address + ".json")
            try content.write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private func createExportOperation(
        address: String,
        password: String,
        chainAccountInfo: ChainAccountInfo,
        metaId: String,
        genesisHash: String?
    ) {
        let chain = chainAccountInfo.chain
        let chainAccount = chainAccountInfo.account
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

        let fileSaveOperation: BaseOperation<RestoreJson> = ClosureOperation { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }
            let content = try exportOperation.extractNoCancellableResultData()
            let fileUrl = try self.saveExportedFile(content, address: address)
            return RestoreJson(
                data: content,
                chain: chain,
                cryptoType: chainAccount.cryptoType,
                fileURL: fileUrl,
                accountId: chainAccount.accountId
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
