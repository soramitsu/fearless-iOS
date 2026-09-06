import BigInt
import Foundation
import RobinHood
import SSFModels

final class AlchemyHistoryOperationFactory: HistoryOperationFactoryProtocol {
    static let cursorKey = "alchemyHistoryV1"
    private let service: AlchemyHistoryFetching

    init(service: AlchemyHistoryFetching = AlchemyService()) {
        self.service = service
    }

    private struct Stream: Codable {
        var started = false
        var pageKey: String?
        var pending: [AlchemyHistoryElement] = []
        var needsPage: Bool { pending.isEmpty && (!started || pageKey != nil) }
        var finished: Bool { started && pageKey == nil && pending.isEmpty }
    }

    private struct Cursor: Codable {
        let chainId: String
        let address: String
        let assetId: String
        var sent = Stream()
        var received = Stream()
    }

    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        if !filters.isEmpty, !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            return .createWithResult(AssetTransactionPageData(transactions: []))
        }
        let operation = AwaitOperation<AssetTransactionPageData?> {
            try await self.fetchPage(asset: asset, chainId: chain.chainId, address: address, pagination: pagination)
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchPage(asset: AssetModel, chainId: String, address: String, pagination: Pagination) async throws -> AssetTransactionPageData {
        guard AlchemyHistoryNetwork.identifier(chainId: chainId) != nil, pagination.count >= 1 else {
            throw AlchemyHistoryError.unsupportedChain
        }
        let limit = min(pagination.count, 100)
        var cursor = Cursor(chainId: chainId, address: address.lowercased(), assetId: asset.id.lowercased())
        if let encoded = pagination.context?[Self.cursorKey] {
            guard encoded.utf8.count <= 512_000, let data = Data(base64Encoded: encoded),
                  let decoded = try? JSONDecoder().decode(Cursor.self, from: data),
                  decoded.chainId == chainId, decoded.address == cursor.address, decoded.assetId == cursor.assetId else {
                throw AlchemyHistoryError.invalidCursor
            }
            cursor = decoded
        }

        cursor.sent = try await load(cursor.sent, sent: true, asset: asset, chainId: chainId, address: address, limit: limit)
        cursor.received = try await load(cursor.received, sent: false, asset: asset, chainId: chainId, address: address, limit: limit)

        var transactions: [AssetTransactionData] = []
        // Merge the ordered streams and retain unconsumed items in the cursor.
        // Advancing both remote page keys here would skip older activity.
        while transactions.count < limit {
            if cursor.sent.needsPage || cursor.received.needsPage { break }
            guard let next = takeNewest(sent: &cursor.sent, received: &cursor.received) else { break }
            if let transaction = transaction(from: next, asset: asset, address: address) {
                transactions.append(transaction)
            }
        }
        let context: PaginationContext?
        if cursor.sent.finished, cursor.received.finished {
            context = nil
        } else {
            context = [Self.cursorKey: try JSONEncoder().encode(cursor).base64EncodedString()]
        }
        return AssetTransactionPageData(transactions: transactions, context: context)
    }

    private func load(_ stream: Stream, sent: Bool, asset: AssetModel, chainId: String, address: String, limit: Int) async throws -> Stream {
        guard stream.needsPage else { return stream }
        let native = asset.ethereumType == .normal
        let categories: [AlchemyTokenCategory] = native ?
            (["1", "137"].contains(chainId) ? [.external, .internal] : [.external]) : [.erc20]
        let request = AlchemyHistoryRequest(
            category: categories, maxCount: "0x" + String(limit, radix: 16),
            fromAddress: sent ? address : nil, toAddress: sent ? nil : address,
            pageKey: stream.pageKey, contractAddresses: native ? nil : [asset.id]
        )
        let result = try await service.fetchTransactionHistory(request: request, chainId: chainId)
        let nextKey = result.pageKey.flatMap { $0.isEmpty ? nil : $0 }
        guard nextKey == nil || nextKey != stream.pageKey else { throw AlchemyHistoryError.invalidResponse }
        var loaded = stream
        loaded.started = true
        loaded.pageKey = nextKey
        loaded.pending = result.transfers.sorted {
            if $0.timestampInSeconds != $1.timestampInSeconds { return $0.timestampInSeconds > $1.timestampInSeconds }
            return $0.uniqueId > $1.uniqueId
        }
        return loaded
    }

    private func takeNewest(sent: inout Stream, received: inout Stream) -> AlchemyHistoryElement? {
        guard let outgoing = sent.pending.first else {
            return received.pending.isEmpty ? nil : received.pending.removeFirst()
        }
        guard let incoming = received.pending.first else { return sent.pending.removeFirst() }
        if outgoing.uniqueId == incoming.uniqueId {
            received.pending.removeFirst()
            return sent.pending.removeFirst()
        }
        if outgoing.timestampInSeconds > incoming.timestampInSeconds ||
            (outgoing.timestampInSeconds == incoming.timestampInSeconds && outgoing.uniqueId > incoming.uniqueId) {
            return sent.pending.removeFirst()
        }
        return received.pending.removeFirst()
    }

    func transaction(from item: AlchemyHistoryElement, asset: AssetModel, address: String) -> AssetTransactionData? {
        let native = asset.ethereumType == .normal
        guard (native && ["external", "internal"].contains(item.category)) ||
            (!native && item.category == "erc20" && item.rawContract?.address?.lowercased() == asset.id.lowercased()),
            item.from.lowercased() == address.lowercased() || item.to?.lowercased() == address.lowercased(),
            item.timestampInSeconds > 0 else { return nil }
        let amount: Decimal?
        if let raw = item.rawContract?.value, raw.hasPrefix("0x"), let integer = BigUInt(String(raw.dropFirst(2)), radix: 16),
           let base = Decimal(string: integer.description, locale: Locale(identifier: "en_US_POSIX")) {
            amount = base / pow(Decimal(10), Int(asset.precision))
        } else {
            amount = item.value
        }
        guard let amount, amount > 0 else { return nil }
        let outgoing = item.from.lowercased() == address.lowercased()
        let peer = outgoing ? (item.to ?? "") : item.from
        return AssetTransactionData(
            transactionId: item.hash, status: .commited, assetId: asset.id,
            peerId: peer, peerFirstName: nil, peerLastName: nil, peerName: peer,
            details: "", amount: AmountDecimal(value: amount), fees: [], timestamp: item.timestampInSeconds,
            type: (outgoing ? TransactionType.outgoing : TransactionType.incoming).rawValue,
            reason: "", context: nil
        )
    }
}
