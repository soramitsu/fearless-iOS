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
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let operationManager: OperationManagerProtocol

    init(
        keystore: KeystoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>
    ) {
        self.keystore = keystore
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.chainRepository = chainRepository
    }
}

extension ExportSeedInteractor: ExportSeedInteractorInputProtocol {
    func fetchExportDataForWallet(_ wallet: MetaAccountModel, accounts: [ChainAccountInfo]) {
        var seeds: [ExportSeedData] = []

        for chainAccount in accounts {
            let chain = chainAccount.chain
            let account = chainAccount.account
            let accountId = account.isChainAccount ? account.accountId : nil

            do {
                let seedTag = chain.isEthereumBased
                    ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                    : KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId)

                var optionalSeed: Data? = try keystore.fetchKey(for: seedTag)

                let keyTag = chain.isEthereumBased
                    ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                    : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

                if optionalSeed == nil, account.cryptoType.supportsSeedFromSecretKey {
                    optionalSeed = try keystore.fetchKey(for: keyTag)
                }

                guard let seed = optionalSeed else {
                    throw ExportSeedInteractorError.missingSeed
                }

                //  We shouldn't show derivation path for ethereum seed. So just provide nil to hide it
                let derivationPathTag = chain.isEthereumBased
                    ? nil : KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)

                var derivationPath: String?
                if let tag = derivationPathTag {
                    derivationPath = try keystore.fetchDeriviationForAddress(tag)
                }

                let seedData = ExportSeedData(
                    seed: seed,
                    derivationPath: derivationPath,
                    chain: chain,
                    cryptoType: account.cryptoType
                )

                seeds.append(seedData)
            } catch {}
        }

        DispatchQueue.main.async { [weak self] in
            self?.presenter.didReceive(exportData: seeds)
        }
    }

    func fetchExportDataForAddress(_ address: String, chain: ChainModel, wallet: MetaAccountModel) {
        fetchChainAccountFor(
            meta: wallet,
            chain: chain,
            address: address
        ) { [weak self] result in
            switch result {
            case let .success(chainRespone):
                guard let response = chainRespone,
                      let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                    self?.presenter.didReceive(error: ExportSeedInteractorError.missingAccount)
                    return
                }
                self?.fetchExportData(
                    metaId: wallet.metaId,
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

            let optionalSeed = try self?.keystore.fetchKey(for: keyTag)

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

                    self?.presenter.didReceive(exportData: [model])
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}

extension ExportSeedInteractor: AccountFetching {}
