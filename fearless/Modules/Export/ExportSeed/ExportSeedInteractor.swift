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
    func fetchExportDataForWallet(_ wallet: MetaAccountModel) {
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

                self?.exportAccounts(chains: chainsToExport, wallet: wallet)
            case .failure:
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            case .none:
                self?.presenter.didReceive(error: AccountExportPasswordInteractorError.missingAccount)
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    func exportAccounts(chains: [ChainModel], wallet: MetaAccountModel) {
        var seeds: [ExportSeedData] = []

        for chain in chains {
            if let chainAccount = wallet.fetch(for: chain.accountRequest()) {
                let accountId = chainAccount.isChainAccount ? chainAccount.accountId : nil

                do {
                    let seedTag = chain.isEthereumBased
                        ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                        : KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId)

                    var optionalSeed: Data? = try keystore.fetchKey(for: seedTag)

                    let keyTag = chain.isEthereumBased
                        ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                        : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

                    if optionalSeed == nil, chainAccount.cryptoType.supportsSeedFromSecretKey {
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
                        cryptoType: chainAccount.cryptoType
                    )

                    seeds.append(seedData)
                } catch {
                    print("Seed creation error:", error)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.presenter.didReceive(exportData: seeds)
        }
    }

    func fetchExportDataForAddress(_ address: String, chain: ChainModel) {
        guard let metaAccount = SelectedWalletSettings.shared.value else {
            presenter.didReceive(error: ExportMnemonicInteractorError.missingAccount)
            return
        }

        fetchChainAccount(
            chain: chain,
            address: address,
            from: accountRepository,
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
            let seedTag = chain.isEthereumBased
                ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
                : KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)

            var optionalSeed: Data? = try self?.keystore.fetchKey(for: seedTag)

            let keyTag = chain.isEthereumBased
                ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
                : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

            if optionalSeed == nil, cryptoType.supportsSeedFromSecretKey {
                optionalSeed = try self?.keystore.fetchKey(for: keyTag)
            }

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
