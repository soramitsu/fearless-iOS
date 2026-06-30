import Foundation

final class BitcoinTransactionHistorySync {
    private let client: BitcoinIndexerClientProtocol

    init(client: BitcoinIndexerClientProtocol) {
        self.client = client
    }

    func historyWindow(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil,
        lastSeenTxid: String? = nil
    ) async throws -> BitcoinTransactionHistoryPage {
        let normalizedAddress = try normalizeHistoryAddress(address, network: network)
        var entries: [BitcoinTransactionHistoryEntry] = []
        var seenTxids = Set<String>()
        var seenCursors = Set<String>()
        var cursor = lastSeenTxid
        var nextLastSeenTxid: String?
        var pagesFetched = 0

        while pagesFetched < bitcoinHistoryMaxPages {
            let currentCursor = cursor
            if let currentCursor, !seenCursors.insert(currentCursor).inserted {
                break
            }

            let page = try await fetchHistoryPage(
                address: normalizedAddress,
                network: network,
                baseURL: baseURL,
                lastSeenTxid: currentCursor,
                mempool: false
            )
            pagesFetched += 1

            var newEntries = 0
            for entry in page.history.entries where seenTxids.insert(entry.txid).inserted {
                entries.append(entry)
                newEntries += 1
            }

            nextLastSeenTxid = page.history.nextLastSeenTxid

            guard
                page.transactionCount >= bitcoinEsploraHistoryPageSize,
                let nextCursor = nextLastSeenTxid,
                nextCursor != currentCursor,
                newEntries > 0
            else {
                break
            }

            cursor = nextCursor
        }

        return BitcoinTransactionHistoryPage(
            address: normalizedAddress,
            network: network,
            entries: entries,
            nextLastSeenTxid: nextLastSeenTxid
        )
    }

    func history(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil,
        lastSeenTxid: String? = nil,
        mempool: Bool = false
    ) async throws -> BitcoinTransactionHistoryPage {
        let normalizedAddress = try normalizeHistoryAddress(address, network: network)
        return try await fetchHistoryPage(
            address: normalizedAddress,
            network: network,
            baseURL: baseURL,
            lastSeenTxid: lastSeenTxid,
            mempool: mempool
        ).history
    }

    private func fetchHistoryPage(
        address: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?,
        lastSeenTxid: String?,
        mempool: Bool
    ) async throws -> BitcoinFetchedHistoryPage {
        let transactions = try await client.transactions(
            address: address,
            network: network,
            baseURL: baseURL,
            lastSeenTxid: lastSeenTxid,
            mempool: mempool
        )
        let entries = transactions.compactMap { normalizeTransaction($0, address: address) }
        let nextLastSeenTxid = transactions.reversed().compactMap { transaction in
            try? BitcoinIndexerRoutes.normalizeTxid(transaction.txid)
        }.first

        return BitcoinFetchedHistoryPage(
            history: BitcoinTransactionHistoryPage(
                address: address,
                network: network,
                entries: entries,
                nextLastSeenTxid: nextLastSeenTxid
            ),
            transactionCount: transactions.count
        )
    }

    private func normalizeHistoryAddress(
        _ address: String,
        network: BitcoinIndexerNetwork
    ) throws -> String {
        do {
            return try BitcoinIndexerRoutes.normalizeAddress(address, network: network)
        } catch {
            throw BitcoinTransactionHistoryError.invalidAddress
        }
    }

    private func normalizeTransaction(
        _ transaction: BitcoinEsploraTransaction,
        address: String
    ) -> BitcoinTransactionHistoryEntry? {
        guard let txid = try? BitcoinIndexerRoutes.normalizeTxid(transaction.txid) else {
            return nil
        }
        let walletAddress = address.lowercased()
        guard
            let sent = sumWalletValues(transaction.vin.compactMap(\.prevout), walletAddress: walletAddress),
            let received = sumWalletValues(transaction.vout, walletAddress: walletAddress),
            sent > 0 || received > 0
        else {
            return nil
        }

        let isOutgoing = sent > 0
        let fee = transaction.fee ?? 0
        guard fee >= 0 else {
            return nil
        }
        let amount = isOutgoing ? sent - received - fee : received
        guard amount > 0, amount <= BitcoinUtxoSelector.maxSatoshi else {
            return nil
        }
        let inputs = transaction.vin.compactMap { $0.prevout?.parsedOutput() }
        let outputs = transaction.vout.compactMap { $0.parsedOutput() }
        let counterparty = isOutgoing
            ? outputs.first { $0.address.lowercased() != walletAddress && $0.valueSats > 0 }?.address
            : inputs.first { $0.address.lowercased() != walletAddress && $0.valueSats > 0 }?.address
        guard let counterparty else {
            return nil
        }

        return BitcoinTransactionHistoryEntry(
            address: address,
            amountSats: amount,
            blockHash: transaction.status.blockHash ?? txid,
            blockHeight: transaction.status.blockHeight,
            confirmed: transaction.status.confirmed,
            feeSats: isOutgoing ? fee : 0,
            from: isOutgoing ? address : counterparty,
            outgoing: isOutgoing,
            timestamp: transaction.status.blockTime ?? 0,
            to: isOutgoing ? counterparty : address,
            txid: txid
        )
    }

    private func sumWalletValues(
        _ outputs: [BitcoinEsploraTransactionOutput],
        walletAddress: String
    ) -> Int64? {
        outputs.reduce(Int64?.some(0)) { result, output -> Int64? in
            guard let total = result else {
                return nil
            }
            guard output.scriptPubKeyAddress?.lowercased() == walletAddress else {
                return total
            }
            guard let parsed = output.parsedOutput() else {
                return nil
            }
            let sum = total.addingReportingOverflow(parsed.valueSats)
            guard !sum.overflow, sum.partialValue <= BitcoinUtxoSelector.maxSatoshi else {
                return nil
            }

            return sum.partialValue
        }
    }
}

private let bitcoinEsploraHistoryPageSize = 25
private let bitcoinHistoryMaxPages = 12

private struct BitcoinFetchedHistoryPage {
    let history: BitcoinTransactionHistoryPage
    let transactionCount: Int
}

struct BitcoinTransactionHistoryPage: Equatable {
    let address: String
    let network: BitcoinIndexerNetwork
    let entries: [BitcoinTransactionHistoryEntry]
    let nextLastSeenTxid: String?
}

struct BitcoinTransactionHistoryEntry: Equatable {
    let address: String
    let amountSats: Int64
    let blockHash: String
    let blockHeight: Int64?
    let confirmed: Bool
    let feeSats: Int64
    let from: String
    let outgoing: Bool
    let timestamp: Int64
    let to: String
    let txid: String
}

enum BitcoinTransactionHistoryError: Error, Equatable {
    case invalidAddress
}

private struct BitcoinParsedTransactionOutput {
    let address: String
    let valueSats: Int64
}

private extension BitcoinEsploraTransactionOutput {
    func parsedOutput() -> BitcoinParsedTransactionOutput? {
        guard let address = scriptPubKeyAddress, !address.isEmpty, let value else {
            return nil
        }
        guard value >= 0, value <= BitcoinUtxoSelector.maxSatoshi else {
            return nil
        }

        return BitcoinParsedTransactionOutput(address: address, valueSats: value)
    }
}
