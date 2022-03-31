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
    func exportWallet(_ account: MetaAccountModel, password: String) {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            switch fetchOperation.result {
            case let .success(chains):
                var chainsToExport: [ChainModel] = []
                if let substrateChain = chains.first(where: { $0.isEthereumBased == false }) {
                    chainsToExport.append(substrateChain)
                }

                if let ethereumChain = chains.first(where: { $0.isEthereumBased == true }) {
                    chainsToExport.append(ethereumChain)
                }

                guard !chainsToExport.isEmpty else {
                    self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
                    return
                }

                self?.exportAccounts(chains: chainsToExport, wallet: account, password: password)
            case .failure:
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            case .none:
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    func exportAccounts(chains: [ChainModel], wallet: MetaAccountModel, password: String) {
        var jsons: [RestoreJson] = []

        for chain in chains {
            if let chainAccount = wallet.fetch(for: chain.accountRequest()), let data = try? exportJsonWrapper.export(
                chainAccount: chainAccount,
                password: password,
                address: AddressFactory.address(for: chainAccount.accountId, chain: chain),
                metaId: wallet.metaId,
                accountId: chainAccount.isChainAccount ? chainAccount.accountId : nil,
                genesisHash: ""
            ), let result = String(data: data, encoding: .utf8) {
                do {
                    let fileUrl = try URL(fileURLWithPath: NSTemporaryDirectory() + "/\(AddressFactory.address(for: chainAccount.accountId, chain: chain)).json")
                    try result.write(toFile: fileUrl.path, atomically: true, encoding: .utf8)
                    let json = RestoreJson(
                        data: result,
                        chain: chain,
                        cryptoType: chainAccount.cryptoType,
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

    func exportAccount(address: String, password: String, chain: ChainModel) {
        fetchChainAccount(
            chain: chain,
            address: address,
            from: accountRepository,
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
                                metaId: metaAccount.metaId,
                                genesisHash: genesisHash
                            )
                        } catch {
                            self?.presenter.didReceive(error: error)
                        }
                    }
                    self.operationManager.enqueue(operations: [genesisOperation], in: .transient)
                } else {
                    self.createExportOperation(
                        address: address,
                        password: password,
                        chain: chain,
                        chainAccount: response,
                        metaId: metaAccount.metaId,
                        genesisHash: ""
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
        genesisHash: String
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

                    self?.presenter.didExport(jsons: [model, model])
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        fileSaveOperation.addDependency(exportOperation)

        operationManager.enqueue(operations: [exportOperation, fileSaveOperation], in: .transient)
    }
}

extension AccountExportPasswordInteractor: AccountFetching {}
