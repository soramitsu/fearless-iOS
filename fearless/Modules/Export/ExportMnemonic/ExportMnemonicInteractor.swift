import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit

enum ExportMnemonicInteractorError: Error {
    case missingAccount
    case missingEntropy
}

final class ExportMnemonicInteractor {
    weak var presenter: ExportMnemonicInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let repository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol
    private var requestId: UUID?

    init(
        keystore: KeystoreProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.keystore = keystore
        self.repository = repository
        self.operationManager = operationManager
    }

    private func fetch(wallet: MetaAccountModel, accounts: [ChainAccountInfo], wholeWallet: Bool) {
        let request = UUID()
        requestId = request
        let reader = VerifiedMnemonicExportReader(keystore: keystore)
        let operation = ClosureOperation<([ExportMnemonicData], [ExportMnemonicNotShown])> {
            var exports: [VerifiedMnemonicExport] = []
            var notShown: [ExportMnemonicNotShown] = []
            for info in accounts {
                do {
                    try exports.append(reader.fetch(wallet: wallet, info: info))
                } catch {
                    notShown.append(ExportMnemonicNotShown(chain: info.chain, error: error))
                }
            }
            let proof = wholeWallet && notShown.isEmpty ? reader.backupProof(wallet: wallet, exports: exports) : nil
            let models = exports.map {
                ExportMnemonicData(
                    mnemonic: $0.mnemonic, derivationPath: $0.derivationPath,
                    cryptoType: $0.info.account.isEthereumBased ? nil : $0.info.account.cryptoType,
                    chain: $0.info.chain, backupProof: proof
                )
            }
            return (models, notShown)
        }
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                operation.completionBlock = nil
                guard let self, self.requestId == request else { return }
                self.requestId = nil
                do {
                    let (models, notShown) = try operation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    self.presenter.didReceive(exportDatas: models, notShown: notShown)
                } catch {
                    self.presenter.didReceive(error: error)
                }
            }
        }
        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

extension ExportMnemonicInteractor: ExportMnemonicInteractorInputProtocol {
    func cancelExport() {
        requestId = nil
    }

    func fetchExportDataForWallet(wallet: MetaAccountModel, accounts: [ChainAccountInfo]) {
        requestId = nil
        guard !accounts.isEmpty else {
            presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
            return
        }
        fetch(wallet: wallet, accounts: accounts, wholeWallet: true)
    }

    func fetchExportDataForAddress(_ address: String, chain: ChainModel, wallet: MetaAccountModel) {
        requestId = nil
        fetchChainAccountFor(meta: wallet, chain: chain, address: address) { [weak self] result in
            guard let self else { return }
            guard case let .success(response) = result, let account = response else {
                self.presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
                return
            }
            // The resolved custom account can differ from the wallet's default for this chain.
            self.fetch(wallet: wallet, accounts: [ChainAccountInfo(chain: chain, account: account)], wholeWallet: false)
        }
    }
}

extension ExportMnemonicInteractor: AccountFetching {}
