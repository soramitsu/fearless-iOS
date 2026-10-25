import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit

enum ExportSeedInteractorError: Error {
    case missingAccount
}

final class ExportSeedInteractor {
    weak var presenter: ExportSeedInteractorOutputProtocol!

    private let seedReader: VerifiedSeedExportReading
    private let backupMarker: WalletBackupMarkerWriting
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol

    init(
        seedReader: VerifiedSeedExportReading,
        backupMarker: WalletBackupMarkerWriting,
        operationManager: OperationManagerProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol
    ) {
        self.seedReader = seedReader
        self.backupMarker = backupMarker
        self.operationManager = operationManager
        self.chainRepository = chainRepository
        self.eventCenter = eventCenter
    }
}

extension ExportSeedInteractor: ExportSeedInteractorInputProtocol {
    func didBackupSeed(wallet: MetaAccountModel, completion: @escaping (Result<Void, Error>) -> Void) {
        let events = eventCenter
        backupMarker.recordBackup(of: wallet) { result in
            if case let .success(savedWallet) = result {
                events.notify(with: MetaAccountModelChangedEvent(account: savedWallet))
            }
            completion(result.map { _ in () })
        }
    }

    func fetchExportDataForWallet(_ wallet: MetaAccountModel, accounts: [ChainAccountInfo]) {
        var seeds: [ExportSeedData] = []
        var notShown: [ExportSeedNotShown] = []

        for chainAccount in accounts {
            let chain = chainAccount.chain
            let account = chainAccount.account

            do {
                // A seed is shown only if importing it recreates this account.
                let export = try seedReader.fetchSeed(
                    metaId: wallet.metaId,
                    accountId: account.isChainAccount ? account.accountId : nil,
                    publicKey: account.publicKey,
                    cryptoType: account.cryptoType,
                    ethereumBased: chain.isEthereumBased
                )

                seeds.append(
                    ExportSeedData(
                        seed: export.seed,
                        derivationPath: export.derivationPath,
                        chain: chain,
                        cryptoType: account.cryptoType
                    )
                )
            } catch {
                notShown.append(ExportSeedNotShown(chain: chain, error: error))
            }
        }

        DispatchQueue.main.async { [weak self] in
            if seeds.isEmpty, let firstError = notShown.first?.error {
                // Say why nothing can be exported instead of showing an empty screen.
                self?.presenter.didReceive(error: firstError)
            } else {
                // Every account left out is reported: a partial export is never a backup.
                self?.presenter.didReceive(exportData: seeds, notShown: notShown)
            }
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
                    publicKey: response.publicKey,
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
        publicKey: Data,
        cryptoType: CryptoType,
        chain: ChainModel
    ) {
        let seedReader = self.seedReader
        let exportOperation: BaseOperation<ExportSeedData> = ClosureOperation {
            let export = try seedReader.fetchSeed(
                metaId: metaId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: cryptoType,
                ethereumBased: chain.isEthereumBased
            )

            return ExportSeedData(
                seed: export.seed,
                derivationPath: export.derivationPath,
                chain: chain,
                cryptoType: cryptoType
            )
        }

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didReceive(exportData: [model], notShown: [])
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}

extension ExportSeedInteractor: AccountFetching {}
