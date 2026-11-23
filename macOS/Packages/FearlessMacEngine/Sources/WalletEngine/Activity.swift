import Foundation
import WalletCore

struct MortalTransfer: Codable {
    let nonce: UInt32
    let birth: UInt64
    var nextHeight: UInt64?
    var exhausted: Bool?
}

/// Keep ActivityItem's original JSON fields so pre-reconciliation records still decode.
struct LocalTransfer: Codable {
    var item: ActivityItem
    var mortality: MortalTransfer?
    enum CodingKeys: String, CodingKey { case mortality }

    init(item: ActivityItem, mortality: MortalTransfer?) {
        self.item = item
        self.mortality = mortality
    }

    init(from decoder: Decoder) throws {
        item = try ActivityItem(from: decoder)
        mortality = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(MortalTransfer.self, forKey: .mortality)
    }

    func encode(to encoder: Encoder) throws {
        try item.encode(to: encoder)
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encodeIfPresent(mortality, forKey: .mortality)
    }
}

extension EngineStore {
    func localTransfers() throws -> [LocalTransfer] {
        try files.read([LocalTransfer].self, "activity.json") ?? []
    }

    func localActivity(_ id: WalletID) throws -> [ActivityItem] {
        try localTransfers().map(\.item).filter { $0.walletID == id }
    }

    func record(_ item: ActivityItem, mortality: MortalTransfer? = nil) throws {
        _ = try wallet(item.walletID)
        var all = try localTransfers()
        let entry = LocalTransfer(item: item, mortality: mortality)
        if let index = all.firstIndex(where: { $0.item.walletID == item.walletID && $0.item.id == item.id }) {
            guard all[index].item.status == .failed else {
                throw WalletError.transferRejected("This signed transaction is already in Activity.")
            }
            all[index] = entry
        } else {
            all.append(entry)
        }
        try files.write(all, "activity.json")
    }

    func discardUnsent(_ item: ActivityItem) throws {
        var rows = try localTransfers()
        guard let index = rows.firstIndex(where: { $0.item == item }) else { return }
        rows.remove(at: index)
        try files.write(rows, "activity.json")
    }

    @discardableResult
    func update(
        _ item: ActivityItem,
        status: ActivityStatus,
        actualFee: TokenAmount? = nil,
        scanned: MortalTransfer? = nil
    ) throws -> ActivityItem? {
        var all = try localTransfers()
        guard let index = all.firstIndex(where: { $0.item.id == item.id && $0.item.walletID == item.walletID }) else { return nil }
        guard all[index].item.status == .pending || status == .failed else { return all[index].item }
        all[index].item.status = status
        if let actualFee {
            all[index].item.fee = actualFee
        }
        if let scanned {
            guard (scanned.nextHeight ?? 0) >= (all[index].mortality?.nextHeight ?? 0) else { return all[index].item }
            all[index].mortality = scanned
            if scanned.exhausted == true {
                all[index].item.title = "Mortal era expired. Final outcome unknown."
            }
        }
        try files.write(all, "activity.json")
        return all[index].item
    }
}

extension NetworkServices: ActivityServicing {
    private struct HistoryResponse: Decodable {
        struct Page: Decodable { let historyElements: [Row] }
        struct Row: Decodable {
            struct Transfer: Decodable {
                let from, to, amount: String
                let fee: String?
            }

            let id: String
            let success: Bool
            let timestamp: Int64
            let extrinsicHash: String?
            let transfer: Transfer?
        }

        let data: Page?
    }

    func history(_ chain: Catalog.Network, wallet: WalletID, address: String, hash: String? = nil) async throws -> [ActivityItem] {
        guard let source = chain.history else { throw WalletError.network("No history indexer is configured.") }
        guard source.type != "oklink" else { throw WalletError.network("The history indexer requires an API key.") }
        guard source.type == "subsquid", let url = URL(string: source.url), let native = chain.assets.first else {
            throw WalletError.network("The configured history indexer is unavailable.")
        }
        var variables = ["account": address]
        variables["hash"] = hash
        let declaration = hash == nil ? "" : ", $hash: String!"
        let condition = hash == nil ? "" : ", extrinsicHash_eq:$hash"
        let query = """
        query WalletHistory($account: String!\(declaration)) {
          historyElements(where:{address_eq:$account, transfer_isNull:false\(condition)}, orderBy:timestamp_DESC, limit:100) {
            id timestamp extrinsicHash success transfer { from to amount fee }
          }
        }
        """
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let page = try JSONDecoder().decode(HistoryResponse.self, from: data).data else {
            throw WalletError.network("The history indexer is unavailable.")
        }
        return page.historyElements.compactMap { row in
            guard let tx = row.transfer, let amount = TokenAmount(units: tx.amount, decimals: native.decimals),
                  tx.from == address || tx.to == address else { return nil }
            let outgoing = tx.from == address, hash = row.extrinsicHash
            return ActivityItem(
                id: chain.id.rawValue + "/" + row.id,
                walletID: wallet,
                assetID: .native(chain.id),
                direction: outgoing && tx.to == address ? .selfTransfer : outgoing ? .outgoing : .incoming,
                counterparty: outgoing ? tx.to : tx.from,
                amount: amount,
                fee: tx.fee.flatMap { TokenAmount(units: $0, decimals: native.decimals) },
                timestamp: Date(timeIntervalSince1970: Double(row.timestamp)),
                status: row.success ? .success : .failed,
                hash: hash,
                explorerURL: hash.flatMap { chain.explorer?.transactionURL(hash: $0) }
            )
        }
    }

    func activity(of walletID: WalletID, assets: [AssetID]?) async throws -> ActivityPage {
        let wallet = try await store.wallet(walletID)
        let filter = assets.map(Set.init)
        let pending = try await store.localTransfers().filter { $0.item.walletID == walletID && filter?.contains($0.item.assetID) != false }
        await reconcile(pending)
        let local = try await store.localActivity(walletID)
        let localItems = local.filter { filter?.contains($0.assetID) != false }
        return await withTaskGroup(of: (ChainID, [ActivityItem], String?).self) { group in
            for chain in Catalog.networks where wallet.ecosystems.contains(chain.prefix == nil ? .evm : .substrate) &&
                (filter?.contains(where: { $0.chainID == chain.id }) ?? true) {
                group.addTask {
                    do {
                        let address = try await self.store.address(of: walletID, on: chain.id)
                        return try await(chain.id, self.history(chain, wallet: walletID, address: address), nil)
                    } catch { return (
                        chain.id,
                        [],
                        (error as? WalletError)?.localizedDescription ?? "History indexer unavailable."
                    ) }
                }
            }
            var items = localItems
            var unavailable: [ChainID: String] = [:]
            for await(chain, rows, error) in group {
                unavailable[chain] = error
                for row in rows where filter?.contains(row.assetID) != false {
                    if let hash = row.hash, let index = items.firstIndex(where: {
                        $0.hash?.lowercased() == hash.lowercased() && $0.assetID == row.assetID && $0.direction == row.direction && $0
                            .amount == row.amount && localItems.contains($0)
                    }) {
                        if items[index].status == .pending,
                           let resolved = try? await store.update(items[index], status: row.status, actualFee: row.fee) {
                            items[index] = resolved
                        }
                    } else {
                        items.append(row)
                    }
                }
            }
            return ActivityPage(items: items.sorted { $0.timestamp > $1.timestamp }, unavailable: unavailable)
        }
    }
}
