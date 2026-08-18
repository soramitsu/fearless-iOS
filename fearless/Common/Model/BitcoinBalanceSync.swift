import Foundation

final class BitcoinBalanceSync {
    private let discovery: BitcoinReceiveDiscovery

    init(discovery: BitcoinReceiveDiscovery) {
        self.discovery = discovery
    }

    func balance(
        mnemonic: String,
        passphrase: String = "",
        network: BitcoinKeyDerivation.Network = .mainnet,
        baseURL: String? = nil,
        gapLimit: Int? = nil,
        maxLookahead: Int = BitcoinReceiveDiscovery.defaultMaxLookahead
    ) async throws -> BitcoinBalanceSyncResult {
        let discoveryResult = try await discovery.discoverWallet(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            baseURL: baseURL,
            gapLimit: gapLimit,
            maxLookahead: maxLookahead
        )
        var confirmedSats: Int64 = 0
        var mempoolSats: Int64 = 0

        for address in discoveryResult.addresses {
            guard address.confirmedSats >= 0, address.totalSats >= 0 else {
                throw BitcoinBalanceSyncError.invalidAddressBalance
            }

            confirmedSats = try safeAdd(confirmedSats, address.confirmedSats)
            mempoolSats = try safeAdd(mempoolSats, address.mempoolSats)
        }

        return BitcoinBalanceSyncResult(
            confirmedSats: confirmedSats,
            mempoolSats: mempoolSats,
            totalSats: try safeAdd(confirmedSats, mempoolSats),
            usedAddresses: discoveryResult.usedAddresses,
            discovery: discoveryResult
        )
    }

    func balance(
        address: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String? = nil
    ) async throws -> BitcoinAddressBalanceResult {
        try await discovery.balance(address: address, network: network, baseURL: baseURL)
    }

    private func safeAdd(_ left: Int64, _ right: Int64) throws -> Int64 {
        let sum = left.addingReportingOverflow(right)
        guard !sum.overflow else {
            throw BitcoinBalanceSyncError.balanceOverflow
        }

        return sum.partialValue
    }
}

struct BitcoinBalanceSyncResult: Equatable {
    let confirmedSats: Int64
    let mempoolSats: Int64
    let totalSats: Int64
    let usedAddresses: [BitcoinReceiveDiscoveredAddress]
    let discovery: BitcoinReceiveDiscoveryResult
}

actor BitcoinWalletBalanceCache {
    struct Key: Hashable {
        let walletId: MetaAccountId
        let network: BitcoinIndexerNetwork
        let baseURL: String?
        let gapLimit: Int
        let maxLookahead: Int
    }

    static let shared = BitcoinWalletBalanceCache()
    static let defaultMaxAge: TimeInterval = 120

    private struct Entry {
        let value: BitcoinBalanceSyncResult
        let createdAt: Date
    }

    private var entries: [Key: Entry] = [:]
    private var inFlight: [Key: Task<BitcoinBalanceSyncResult, Error>] = [:]

    func value(
        for key: Key,
        maxAge: TimeInterval = BitcoinWalletBalanceCache.defaultMaxAge,
        loader: @escaping () async throws -> BitcoinBalanceSyncResult
    ) async throws -> BitcoinBalanceSyncResult {
        if let entry = entries[key],
           Date().timeIntervalSince(entry.createdAt) <= maxAge {
            return entry.value
        }

        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task {
            try await loader()
        }
        inFlight[key] = task

        do {
            let result = try await task.value
            entries[key] = Entry(value: result, createdAt: Date())
            inFlight[key] = nil
            return result
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    func invalidate(_ key: Key) {
        entries[key] = nil
    }
}

enum BitcoinBalanceSyncError: Error, Equatable {
    case invalidAddressBalance
    case balanceOverflow
}

struct BitcoinAddressBalanceResult: Equatable {
    let confirmedSats: Int64
    let mempoolSats: Int64
    let totalSats: Int64
}
