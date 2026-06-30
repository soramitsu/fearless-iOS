import Foundation

final class BitcoinTransactionBroadcaster {
    private let client: BitcoinIndexerClientProtocol

    init(client: BitcoinIndexerClientProtocol) {
        self.client = client
    }

    func broadcast(
        txHex: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinBroadcastResult {
        let normalizedTxHex: String
        do {
            normalizedTxHex = try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody(txHex)
        } catch {
            throw BitcoinBroadcastError.invalidTxHex
        }

        let txid = try await client.broadcastTransaction(
            txHex: normalizedTxHex,
            network: network,
            baseURL: baseURL
        )
        let normalizedTxid: String
        do {
            normalizedTxid = try BitcoinIndexerRoutes.normalizeTxid(txid)
        } catch {
            throw BitcoinBroadcastError.invalidTxidResponse
        }

        return BitcoinBroadcastResult(
            network: network,
            txHex: normalizedTxHex,
            txid: normalizedTxid
        )
    }
}

struct BitcoinBroadcastResult: Equatable {
    let network: BitcoinIndexerNetwork
    let txHex: String
    let txid: String
}

enum BitcoinBroadcastError: Error, Equatable {
    case invalidTxHex
    case invalidTxidResponse
}
