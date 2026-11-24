import Foundation
import Observation
import WalletCore

/// One line of the activity table with its asset and network resolved.
struct ActivityRow: Identifiable, Equatable {
    let item: ActivityItem
    let asset: Asset?
    let chain: Chain?

    var id: String { item.id }

    var typeName: String {
        switch item.direction {
        case .outgoing: return "Sent"
        case .incoming: return "Received"
        case .selfTransfer: return "To Self"
        case .other: return item.title ?? "Other"
        }
    }

    var typeSymbol: String {
        switch item.direction {
        case .outgoing: return "arrow.up.right"
        case .incoming: return "arrow.down.left"
        case .selfTransfer: return "arrow.triangle.2.circlepath"
        case .other: return "sparkles"
        }
    }

    var statusName: String {
        switch item.status {
        case .pending: return "Pending"
        case .success: return "Confirmed"
        case .failed: return "Failed"
        }
    }

    var symbol: String { asset?.symbol ?? "?" }

    // Sort keys.
    var sortDate: Date { item.timestamp }
    var sortType: String { typeName }
    var sortAsset: String { symbol.lowercased() + " " + (chain?.name.lowercased() ?? "") }
    var sortAmount: Decimal { item.amount.decimalValue }
    var sortCounterparty: String { item.counterparty?.lowercased() ?? "" }
    var sortStatus: String { statusName }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return symbol.lowercased().contains(needle)
            || (asset?.name.lowercased().contains(needle) ?? false)
            || (chain?.name.lowercased().contains(needle) ?? false)
            || (item.counterparty?.lowercased().contains(needle) ?? false)
            || (item.hash?.lowercased().contains(needle) ?? false)
            || typeName.lowercased().contains(needle)
            || statusName.lowercased().contains(needle)
    }
}

/// Which activity the table shows.
struct ActivityFilter: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case all = "All"
        case sent = "Sent"
        case received = "Received"
        case other = "Other"

        var id: String { rawValue }
    }

    var kind: Kind = .all
    var status: ActivityStatus?
    var search = ""
    var showTestnets = false

    func apply(to rows: [ActivityRow]) -> [ActivityRow] {
        rows.filter { row in
            if !showTestnets, row.chain?.isTestnet == true { return false }
            switch kind {
            case .all: break
            case .sent: if row.item.direction != .outgoing { return false }
            case .received: if row.item.direction != .incoming { return false }
            case .other: if row.item.direction != .other && row.item.direction != .selfTransfer { return false }
            }
            if let status, row.item.status != status { return false }
            return row.matches(search)
        }
    }
}

/// The selected wallet's history.
@MainActor
@Observable
final class ActivityStore {
    @ObservationIgnored private let services: WalletServices

    private(set) var items: [ActivityItem] = []
    /// Networks whose history could not be loaded, with the reason.
    private(set) var unavailable: [ChainID: String] = [:]
    private(set) var state: LoadState = .idle
    private(set) var walletID: WalletID?
    @ObservationIgnored private var generation = 0

    init(services: WalletServices) {
        self.services = services
    }

    func reset() {
        generation += 1
        items = []
        unavailable = [:]
        state = .idle
        walletID = nil
    }

    func refresh(wallet: Wallet) async {
        generation += 1
        let current = generation
        if walletID != wallet.id {
            items = []
            unavailable = [:]
            walletID = wallet.id
        }
        state = .loading
        do {
            let page = try await services.activity.activity(of: wallet.id, assets: nil)
            guard current == generation else { return }
            items = page.items.sorted { $0.timestamp > $1.timestamp }
            unavailable = page.unavailable
            state = .loaded
        } catch {
            guard current == generation else { return }
            state = .failed(ErrorText.message(for: error))
        }
    }

    func rows(assets: [Asset], chains: [Chain]) -> [ActivityRow] {
        let assetByID = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let chainByID = Dictionary(chains.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return items.map { ActivityRow(item: $0, asset: assetByID[$0.assetID], chain: chainByID[$0.assetID.chainID]) }
    }

    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }
}
