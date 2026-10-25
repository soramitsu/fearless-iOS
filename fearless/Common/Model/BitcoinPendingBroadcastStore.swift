import Foundation

/// A signed Bitcoin transaction the wallet handed to the network without learning whether the
/// network took it. While one exists for a wallet, the wallet must not build another payment
/// from different coins: if the first is still in flight, both would confirm and the user
/// would pay twice. It holds the signed transaction (public data once broadcast) and never
/// any key material.
struct BitcoinPendingBroadcast: Codable, Equatable {
    struct Input: Codable, Equatable {
        let txid: String
        let vout: Int64
        let valueSats: Int64

        var outpoint: BitcoinOutpoint {
            BitcoinOutpoint(txid: txid, vout: vout)
        }
    }

    /// An earlier unresolved transfer the user chose to replace with this one. It spends some
    /// of the same coins, so at most one of the two can ever confirm.
    struct Replaced: Codable, Equatable {
        let txid: String
        let amountSats: Int64
        let recipientAddress: String
    }

    let walletId: String
    let chainId: String
    let txid: String
    let txHex: String
    let amountSats: Int64
    let feeSats: Int64
    let recipientAddress: String
    let inputs: [Input]
    let createdAt: Date
    /// Set when the user chose to replace this transfer. The next payment must then spend
    /// every one of `inputs`, which makes it conflict with this transaction.
    var replacementAllowedAt: Date?
    var replaced: [Replaced]

    init(
        walletId: String,
        chainId: String,
        txid: String,
        txHex: String,
        amountSats: Int64,
        feeSats: Int64,
        recipientAddress: String,
        inputs: [Input],
        createdAt: Date,
        replacementAllowedAt: Date? = nil,
        replaced: [Replaced] = []
    ) {
        self.walletId = walletId
        self.chainId = chainId
        self.txid = txid
        self.txHex = txHex
        self.amountSats = amountSats
        self.feeSats = feeSats
        self.recipientAddress = recipientAddress
        self.inputs = inputs
        self.createdAt = createdAt
        self.replacementAllowedAt = replacementAllowedAt
        self.replaced = replaced
    }

    var asReplaced: Replaced {
        Replaced(txid: txid, amountSats: amountSats, recipientAddress: recipientAddress)
    }

    /// The transfers a payment replacing this one supersedes: this one and everything it
    /// replaced itself.
    var replacementLineage: [Replaced] {
        replaced + [asReplaced]
    }
}

/// One wallet on one Bitcoin network. Chain aliases (`bitcoin:mainnet`, `bitcoin-mainnet`)
/// resolve to the same scope so a record written under one is found under the other.
struct BitcoinPendingBroadcastScope: Hashable {
    let walletId: String
    let chainId: String

    init(walletId: String, chainId: String) {
        self.walletId = walletId
        self.chainId = UniversalWalletRegistry.bitcoinNetwork(for: chainId)?.chainId ?? chainId.lowercased()
    }
}

protocol BitcoinPendingBroadcastStoring: AnyObject {
    func pending(for scope: BitcoinPendingBroadcastScope) -> BitcoinPendingBroadcast?
    func save(_ record: BitcoinPendingBroadcast, for scope: BitcoinPendingBroadcastScope) throws
    /// Removes the record only if it is still the one for `txid`.
    func clear(txid: String, for scope: BitcoinPendingBroadcastScope)
}

enum BitcoinPendingBroadcastStoreError: Error, Equatable {
    case notPersisted
}

/// `UserDefaults` keeps the record across app restarts, so a transfer interrupted by a crash
/// or a kill between signing and the node's reply is still known on the next launch.
final class BitcoinPendingBroadcastStore: BitcoinPendingBroadcastStoring {
    static let shared = BitcoinPendingBroadcastStore()

    private static let keyPrefix = "bitcoin.pending_broadcast"
    private static let unreadableKeyPrefix = "bitcoin.pending_broadcast.unreadable"
    private static let lock = NSLock()

    private let userDefaults: UserDefaults
    private let logger: LoggerProtocol?

    init(userDefaults: UserDefaults = .standard, logger: LoggerProtocol? = Logger.shared) {
        self.userDefaults = userDefaults
        self.logger = logger
    }

    func pending(for scope: BitcoinPendingBroadcastScope) -> BitcoinPendingBroadcast? {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let key = Self.key(for: scope)
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            return try Self.decoder.decode(BitcoinPendingBroadcast.self, from: data)
        } catch {
            // Only this class writes the key, so this means a damaged preference file. Keep
            // the bytes for diagnosis instead of deleting them, and do not let them lock the
            // wallet's Bitcoin forever.
            userDefaults.set(data, forKey: Self.unreadableKey(for: scope))
            userDefaults.removeObject(forKey: key)
            logger?.error("Unreadable Bitcoin pending broadcast record was set aside: \(error)")
            return nil
        }
    }

    func save(_ record: BitcoinPendingBroadcast, for scope: BitcoinPendingBroadcastScope) throws {
        let data = try Self.encoder.encode(record)

        Self.lock.lock()
        defer { Self.lock.unlock() }

        let key = Self.key(for: scope)
        userDefaults.set(data, forKey: key)
        guard userDefaults.data(forKey: key) == data else {
            throw BitcoinPendingBroadcastStoreError.notPersisted
        }
    }

    func clear(txid: String, for scope: BitcoinPendingBroadcastScope) {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let key = Self.key(for: scope)
        guard
            let data = userDefaults.data(forKey: key),
            let record = try? Self.decoder.decode(BitcoinPendingBroadcast.self, from: data),
            record.txid == txid
        else {
            return
        }
        userDefaults.removeObject(forKey: key)
    }

    static func key(for scope: BitcoinPendingBroadcastScope) -> String {
        [keyPrefix, scope.walletId, scope.chainId].joined(separator: ":")
    }

    private static func unreadableKey(for scope: BitcoinPendingBroadcastScope) -> String {
        [unreadableKeyPrefix, scope.walletId, scope.chainId].joined(separator: ":")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

/// What the indexers can prove about a transfer whose broadcast outcome is unknown.
enum BitcoinPendingBroadcastStatus: Equatable {
    /// An indexer has the transaction, in its mempool or in a block: it was sent.
    case seen(confirmed: Bool)
    /// A transfer this one was meant to replace is the one that reached the network.
    case replacedTransferSeen(txid: String)
    /// A coin it spends was spent by a different confirmed transaction: it can never confirm.
    case dead
    /// Nothing proves either outcome; it may still be in flight.
    case unknown
}

/// Looks an unresolved transfer up without building or signing anything.
final class BitcoinPendingBroadcastResolver {
    private let client: BitcoinIndexerClientProtocol

    init(client: BitcoinIndexerClientProtocol) {
        self.client = client
    }

    func status(
        of record: BitcoinPendingBroadcast,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async -> BitcoinPendingBroadcastStatus {
        if let status = try? await client.transactionStatus(txid: record.txid, network: network, baseURL: baseURL) {
            return .seen(confirmed: status.confirmed)
        }
        for replaced in record.replaced.reversed() {
            let status = try? await client.transactionStatus(txid: replaced.txid, network: network, baseURL: baseURL)
            if status != nil {
                return .replacedTransferSeen(txid: replaced.txid)
            }
        }

        // The mempool view of one service can lag another's, but who spent a coin is a fact:
        // if anything other than this transaction spent one of its inputs in a block, this
        // transaction is invalid for good.
        for input in record.inputs {
            guard
                let outspend = try? await client.outspend(
                    txid: input.txid,
                    vout: input.vout,
                    network: network,
                    baseURL: baseURL
                ),
                outspend.spent,
                let spender = outspend.txid?.lowercased()
            else {
                continue
            }

            if spender == record.txid.lowercased() {
                return .seen(confirmed: outspend.status?.confirmed ?? false)
            }
            if let replaced = record.replaced.first(where: { $0.txid.lowercased() == spender }) {
                return .replacedTransferSeen(txid: replaced.txid)
            }
            if outspend.status?.confirmed == true {
                return .dead
            }
        }

        return .unknown
    }
}
