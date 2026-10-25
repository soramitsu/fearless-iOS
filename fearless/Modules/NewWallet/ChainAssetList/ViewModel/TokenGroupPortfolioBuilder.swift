import Foundation
import SSFModels

/// The same per-asset valuation and visibility used by the network lens.
struct TokenGroupChildModel: Equatable {
    let chainAsset: ChainAsset
    let value: PortfolioHoldingValue
    let placement: PortfolioPlacement

    var networkName: String { chainAsset.chain.name }
    var amount: Decimal { value.amount }
    var fiat: Decimal { value.role == .counted ? value.fiat : .zero }
}

struct TokenGroupRowModel: Equatable {
    let id: String
    let symbol: String
    let name: String
    let icon: URL?
    let amount: Decimal
    let fiat: Decimal
    let unpricedNetworkCount: Int
    /// Main children and available, unfunded networks stay separate. Expanding
    /// a group never silently promotes an Auto zero holding into the main list.
    let children: [TokenGroupChildModel]
    let zeroChildren: [TokenGroupChildModel]
    let isSingleNetwork: Bool

    var zeroChildrenCount: Int { zeroChildren.count }
    var allChildren: [TokenGroupChildModel] { children + zeroChildren }
}

/// Groups exact, reviewed identities only. Input values are already converted
/// at each asset's own precision and price; no group-level price is consulted.
struct TokenGroupPortfolioBuilder {
    let catalog: CanonicalTokenGroupCatalog

    init(catalog: CanonicalTokenGroupCatalog = .bundled) {
        self.catalog = catalog
    }

    func build(
        candidates: [TokenGroupChildModel],
        wallet: MetaAccountModel,
        search: String? = nil
    ) -> [TokenGroupRowModel] {
        var seen = Set<AssetKey>()
        let eligible = candidates.filter { candidate in
            let asset = candidate.chainAsset
            let hasAccount = wallet.fetch(for: asset.chain.accountRequest()) != nil &&
                !PortfolioVisibilityContext.lacksAppOwnedAccount(asset, wallet: wallet)
            guard hasAccount || (candidate.placement == .visible && PortfolioVisibilityContext.offersAccountSetup(asset, wallet: wallet)) else {
                return false
            }
            return !asset.chain.disabled && candidate.value.role != .hidden &&
                (candidate.placement == .visible || candidate.placement == .zeroCollapsed) &&
                seen.insert(asset.assetKey).inserted
        }
        // A wallet without a usable account cannot make a second group member
        // active. Explicit account-setup rows can still appear as single rows.
        let grouped = Dictionary(grouping: eligible.filter {
            wallet.fetch(for: $0.chainAsset.chain.accountRequest()) != nil &&
                !PortfolioVisibilityContext.lacksAppOwnedAccount($0.chainAsset, wallet: wallet) &&
                $0.value.role != .unverified && $0.value.role != .testnet &&
                catalog.group(for: $0.chainAsset) != nil
        }, by: { catalog.group(for: $0.chainAsset)?.id ?? "" })
        let activeGroups = grouped.filter { $0.value.count >= 2 }
        var emittedGroups = Set<String>()
        let query = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var rows: [TokenGroupRowModel] = []
        var completeMembers: [String: [TokenGroupChildModel]] = [:]
        for candidate in eligible {
            let group = catalog.group(for: candidate.chainAsset)
            let members: [TokenGroupChildModel]
            let identity: String
            let isSingle: Bool
            if let group, let active = activeGroups[group.id],
               active.contains(where: { $0.chainAsset.assetKey == candidate.chainAsset.assetKey }) {
                guard emittedGroups.insert(group.id).inserted else { continue }
                members = active
                identity = "group:" + group.id
                isSingle = false
            } else {
                members = [candidate]
                identity = "asset:" + candidate.chainAsset.identifier
                isSingle = true
            }
            let symbol = isSingle ? candidate.chainAsset.asset.symbolUppercased : (group?.symbol ?? candidate.chainAsset.asset.symbolUppercased)
            let name = isSingle ? candidate.chainAsset.asset.name : (group?.name ?? candidate.chainAsset.asset.name)
            let tokenMatches = query.isEmpty || Self.matches(query, in: symbol) || Self.matches(query, in: name)
            let matching = members.filter { tokenMatches || Self.matches(query, in: $0.networkName) }
            let visible = matching.filter { $0.placement == .visible }.sorted(by: Self.childPrecedes)
            guard !visible.isEmpty else { continue }
            let zero = matching.filter { $0.placement == .zeroCollapsed && !$0.value.isFunded }.sorted(by: Self.childPrecedes)
            completeMembers[identity] = members
            rows.append(TokenGroupRowModel(
                id: identity, symbol: symbol, name: name, icon: visible.first?.chainAsset.asset.icon,
                amount: visible.reduce(.zero) { $0 + $1.amount },
                fiat: visible.reduce(.zero) { $0 + $1.fiat },
                unpricedNetworkCount: Set(visible.filter { $0.value.isFunded && $0.value.role == .unpriced }.map { $0.chainAsset.chain.chainId }).count,
                children: visible, zeroChildren: zero, isSingleNetwork: isSingle
            ))
        }
        let order = Dictionary((wallet.assetKeysOrder ?? []).enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        func customPosition(_ row: TokenGroupRowModel) -> Int {
            (completeMembers[row.id] ?? row.allChildren).compactMap { child -> Int? in
                guard let account = wallet.fetch(for: child.chainAsset.chain.accountRequest()) else { return nil }
                return order[child.chainAsset.uniqueKey(accountId: account.accountId)]
            }.min() ?? Int.max
        }
        return rows.sorted { lhs, rhs in
            let leftPosition = customPosition(lhs), rightPosition = customPosition(rhs)
            if leftPosition != rightPosition { return leftPosition < rightPosition }
            if lhs.fiat != rhs.fiat { return lhs.fiat > rhs.fiat }
            if (lhs.amount > .zero) != (rhs.amount > .zero) { return lhs.amount > .zero }
            if lhs.amount == .zero, rhs.amount == .zero {
                let leftRank = lhs.allChildren.compactMap { $0.chainAsset.chain.rank }.min() ?? UInt16.max
                let rightRank = rhs.allChildren.compactMap { $0.chainAsset.chain.rank }.min() ?? UInt16.max
                if leftRank != rightRank { return leftRank < rightRank }
            }
            let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        }
    }

    private static func matches(_ query: String, in text: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func childPrecedes(_ lhs: TokenGroupChildModel, _ rhs: TokenGroupChildModel) -> Bool {
        if lhs.fiat != rhs.fiat { return lhs.fiat > rhs.fiat }
        let leftRank = lhs.chainAsset.chain.rank ?? UInt16.max
        let rightRank = rhs.chainAsset.chain.rank ?? UInt16.max
        if leftRank != rightRank { return leftRank < rightRank }
        return (lhs.networkName, lhs.chainAsset.identifier) < (rhs.networkName, rhs.chainAsset.identifier)
    }
}
