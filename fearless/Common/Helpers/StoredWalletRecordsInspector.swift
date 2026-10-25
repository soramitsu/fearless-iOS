import Foundation
import RobinHood
import SoraKeystore
import SSFModels

/// What the wallet store holds beyond the wallets and accounts the app shows.
/// Nothing listed here is deleted or rewritten by reading it.
struct StoredWalletRecordsReport: Equatable {
    struct Wallet: Equatable {
        let metaId: MetaAccountId
        let name: String
        /// Stored per-chain accounts the wallet does not use at the moment.
        let alternatives: [ChainAccountModel]
        /// Per-chain account rows that were skipped because they failed validation.
        let unusable: [UnusableStoredChainAccount]
    }

    static let empty = StoredWalletRecordsReport(unavailableWalletCount: 0, wallets: [])

    /// Stored wallets that cannot be shown. Their records and keys stay on the device.
    let unavailableWalletCount: Int
    /// Shown wallets that carry alternatives or skipped rows, ordered by identifier.
    let wallets: [Wallet]

    var unusableChainAccountCount: Int {
        wallets.reduce(0) { $0 + $1.unusable.count }
    }

    func alternatives(for walletId: MetaAccountId) -> [ChainAccountModel] {
        wallets.first { $0.metaId == walletId }?.alternatives ?? []
    }
}

/// Something about the stored wallet records that the user has not been told yet.
enum StoredWalletRecordsNotice: Equatable {
    /// Stored wallets or per-chain accounts that cannot be shown.
    case recordsNotShown(wallets: Int, chainAccounts: Int)
    /// Wallets that keep per-chain accounts which are not in use.
    case storedChainAccounts(walletIds: [MetaAccountId], walletNames: [String])
}

/// The wording for stored records that cannot be shown. One place, so the wallet list
/// and the notice after an update say the same thing.
enum StoredWalletRecordsNoticeText {
    /// One short line per kind of record, or nil when every stored record is shown.
    static func summary(wallets: Int, chainAccounts: Int, locale: Locale) -> String? {
        let languages = locale.rLanguages
        var lines: [String] = []

        if wallets > 0 {
            lines.append(
                R.string.localizable.walletRecordsNoticeWallets(format: wallets, preferredLanguages: languages)
            )
        }
        if chainAccounts > 0 {
            lines.append(
                R.string.localizable.walletRecordsNoticeAccounts(format: chainAccounts, preferredLanguages: languages)
            )
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// What happened, that nothing was deleted, and what the user can do now.
    static func explanation(wallets: Int, chainAccounts: Int, locale: Locale) -> String {
        let languages = locale.rLanguages
        var paragraphs: [String] = []

        if wallets > 0 {
            paragraphs.append(
                R.string.localizable.walletRecordsSheetWallets(format: wallets, preferredLanguages: languages)
            )
        }
        if chainAccounts > 0 {
            paragraphs.append(
                R.string.localizable.walletRecordsSheetAccounts(format: chainAccounts, preferredLanguages: languages)
            )
        }
        paragraphs.append(R.string.localizable.walletRecordsSheetKept(preferredLanguages: languages))
        paragraphs.append(R.string.localizable.walletRecordsSheetNext(preferredLanguages: languages))

        return paragraphs.joined(separator: "\n\n")
    }
}

protocol StoredWalletRecordsNoticeTracking {
    func pendingNotices(for report: StoredWalletRecordsReport) -> [StoredWalletRecordsNotice]
    func acknowledgeRecordsNotShown(in report: StoredWalletRecordsReport)
    func acknowledgeStoredChainAccounts(in report: StoredWalletRecordsReport)
    func acknowledgeStoredChainAccounts(of walletId: MetaAccountId, in report: StoredWalletRecordsReport)
}

/// Remembers which notices about stored wallet records were shown, so each is shown once:
/// again only when another wallet or account becomes affected.
final class StoredWalletRecordsNoticeTracker: StoredWalletRecordsNoticeTracking {
    private let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    func pendingNotices(for report: StoredWalletRecordsReport) -> [StoredWalletRecordsNotice] {
        var notices: [StoredWalletRecordsNotice] = []

        if
            report.unavailableWalletCount > 0 || report.unusableChainAccountCount > 0,
            settings.acknowledgedRecordsNotShown != Self.recordsNotShownSignature(for: report) {
            notices.append(
                .recordsNotShown(
                    wallets: report.unavailableWalletCount,
                    chainAccounts: report.unusableChainAccountCount
                )
            )
        }

        let acknowledged = Set(settings.acknowledgedStoredChainAccounts)
        let affected = report.wallets.filter { wallet in
            Self.identifiers(for: wallet).contains { !acknowledged.contains($0) }
        }
        if !affected.isEmpty {
            notices.append(
                .storedChainAccounts(
                    walletIds: affected.map(\.metaId),
                    walletNames: affected.map(\.name)
                )
            )
        }

        return notices
    }

    func acknowledgeRecordsNotShown(in report: StoredWalletRecordsReport) {
        let recordsNotShown = report.unavailableWalletCount > 0 || report.unusableChainAccountCount > 0
        settings.acknowledgedRecordsNotShown = recordsNotShown
            ? Self.recordsNotShownSignature(for: report)
            : nil
    }

    func acknowledgeStoredChainAccounts(in report: StoredWalletRecordsReport) {
        acknowledge(report.wallets)
    }

    /// The user acted on this wallet's accounts, so it needs no notice; others still do.
    func acknowledgeStoredChainAccounts(of walletId: MetaAccountId, in report: StoredWalletRecordsReport) {
        acknowledge(report.wallets.filter { $0.metaId == walletId })
    }

    private func acknowledge(_ wallets: [StoredWalletRecordsReport.Wallet]) {
        let identifiers = wallets.flatMap(Self.identifiers)
        let acknowledged = Set(settings.acknowledgedStoredChainAccounts).union(identifiers)
        settings.acknowledgedStoredChainAccounts = acknowledged.sorted()
    }

    private static func recordsNotShownSignature(for report: StoredWalletRecordsReport) -> String {
        "\(report.unavailableWalletCount):\(report.unusableChainAccountCount)"
    }

    private static func identifiers(for wallet: StoredWalletRecordsReport.Wallet) -> [String] {
        wallet.alternatives.map {
            [wallet.metaId, $0.chainId, $0.accountId.toHex()].joined(separator: "|")
        }
    }
}

protocol StoredWalletRecordsInspecting {
    func fetchReportOperation() -> BaseOperation<StoredWalletRecordsReport>

    /// Switches what a wallet uses on one chain and returns the wallet as stored afterwards.
    /// Only the in-use marking of that chain's rows changes; no account or key is removed.
    func selectChainAccountOperation(
        _ update: ChainAccountSelectionUpdate,
        walletId: MetaAccountId
    ) -> BaseOperation<MetaAccountModel>
}

final class StoredWalletRecordsInspector: StoredWalletRecordsInspecting {
    private typealias ProjectionRepository = CoreDataRepository<MetaAccountSelectionModel, CDMetaAccount>

    private let storageFacade: StorageFacadeProtocol
    private let operationQueue = OperationQueue()

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func fetchReportOperation() -> BaseOperation<StoredWalletRecordsReport> {
        ClosureOperation {
            let projections = try self.fetchProjections()

            let wallets: [StoredWalletRecordsReport.Wallet] = projections.compactMap { projection in
                guard
                    let wallet = projection.wallet,
                    let records = projection.chainAccountRecords,
                    !records.alternatives.isEmpty || !records.unusable.isEmpty
                else {
                    return nil
                }

                return StoredWalletRecordsReport.Wallet(
                    metaId: wallet.metaId,
                    name: wallet.name,
                    alternatives: records.alternatives,
                    unusable: records.unusable
                )
            }

            return StoredWalletRecordsReport(
                unavailableWalletCount: projections.filter { $0.wallet == nil }.count,
                wallets: wallets.sorted { $0.metaId < $1.metaId }
            )
        }
    }

    func selectChainAccountOperation(
        _ update: ChainAccountSelectionUpdate,
        walletId: MetaAccountId
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let repository = self.createRepository()
            let saveOperation = repository.saveOperation({
                [
                    MetaAccountSelectionModel(
                        identifier: walletId,
                        wallet: nil,
                        isSelected: false,
                        order: ManagedMetaAccountModel.noOrder,
                        updatesSelection: false,
                        chainAccountSelection: update
                    )
                ]
            }, { [] })
            _ = try self.execute(saveOperation)

            guard let wallet = try self.fetchProjections().first(where: { $0.identifier == walletId })?.wallet else {
                throw MetaAccountMapperError.invalidWalletRecord
            }

            return wallet
        }
    }

    private func createRepository() -> ProjectionRepository {
        storageFacade.createRepository(mapper: AnyCoreDataMapper(MetaAccountSelectionMapper()))
    }

    private func fetchProjections() throws -> [MetaAccountSelectionModel] {
        let operation = createRepository().fetchAllOperation(
            with: RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        )

        return try execute(operation)
    }

    private func execute<Result>(_ operation: BaseOperation<Result>) throws -> Result {
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }
}

extension AccountRepositoryFactory {
    func createStoredWalletRecordsInspector() -> StoredWalletRecordsInspecting {
        StoredWalletRecordsInspector(storageFacade: storageFacade)
    }
}
