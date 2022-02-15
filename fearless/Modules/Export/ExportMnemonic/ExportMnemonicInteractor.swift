import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

enum ExportMnemonicInteractorError: Error {
    case missingAccount
    case missingEntropy
}

final class ExportMnemonicInteractor {
    weak var presenter: ExportMnemonicInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let repository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol

    init(
        keystore: KeystoreProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.keystore = keystore
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension ExportMnemonicInteractor: ExportMnemonicInteractorInputProtocol {
    func fetchExportDataForAddress(_ address: String, chain: ChainModel) {
        fetchChainAccount(
            chain: chain,
            address: address,
            from: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(chainRespone):
                guard let response = chainRespone else {
                    self?.presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
                    return
                }
                self?.fetchExportData(
                    address: address,
                    cryptoType: response.cryptoType
                )
            case .failure:
                self?.presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
            }
        }
    }

    private func fetchExportData(
        address: String,
        cryptoType: CryptoType
    ) {
        let exportOperation: BaseOperation<ExportMnemonicData> = ClosureOperation { [weak self] in
            guard let entropy = try self?.keystore.fetchEntropyForAddress(address) else {
                throw ExportMnemonicInteractorError.missingEntropy
            }

            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)

            let derivationPath: String? = try self?.keystore.fetchDeriviationForAddress(address)

            return ExportMnemonicData(
                mnemonic: mnemonic,
                derivationPath: derivationPath,
                cryptoType: cryptoType
            )
        }

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
        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}

extension ExportMnemonicInteractor: AccountFetching {}
