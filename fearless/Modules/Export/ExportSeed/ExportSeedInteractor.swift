import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

enum ExportSeedInteractorError: Error {
    case missingSeed
    case missingAccount
}

final class ExportSeedInteractor {
    weak var presenter: ExportSeedInteractorOutputProtocol!

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

extension ExportSeedInteractor: ExportSeedInteractorInputProtocol {
    func fetchExportDataForAddress(_ address: String, chain: ChainModel) {
        guard let metaAccount = SelectedWalletSettings.shared.value else {
            presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
            return
        }

        fetchChainAccount(
            chain: chain,
            address: address,
            from: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(chainRespone):
                guard let response = chainRespone,
                      let accountId = metaAccount.fetch(for: chain.accountRequest())?.accountId else {
                    self?.presenter.didReceive(error: ExportSeedInteractorError.missingAccount)
                    return
                }
                self?.fetchExportData(
                    metaId: metaAccount.metaId,
                    accountId: response.isChainAccount ? accountId : nil,
                    cryptoType: response.cryptoType,
                    chain: chain
                )
            case .failure:
                self?.presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
            }
        }
    }

    private func fetchExportData(
        metaId: String,
        accountId: AccountId?,
        cryptoType: CryptoType,
        chain: ChainModel
    ) {
        let exportOperation: BaseOperation<ExportSeedData> = ClosureOperation { [weak self] in
            let keyTag = chain.isEthereumBased
                ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
                : KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)

            var optionalSeed = try self?.keystore.fetchKey(for: keyTag)

            guard let seed = optionalSeed else {
                throw ExportSeedInteractorError.missingSeed
            }

            //  We shouldn't show derivation path for ethereum seed. So just provide nil to hide it
            let derivationPathTag = chain.isEthereumBased
                ? nil : KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)

            var derivationPath: String?
            if let tag = derivationPathTag {
                derivationPath = try self?.keystore.fetchDeriviationForAddress(tag)
            }

            return ExportSeedData(
                seed: seed,
                derivationPath: derivationPath,
                chain: chain,
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

extension ExportSeedInteractor: AccountFetching {}
