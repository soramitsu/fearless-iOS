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

        // The same addresses a transfer spends from (`BitcoinTransferService`), so the balance
        // Send offers is exactly what the planner can select.
        var confirmedSpendableSats: Int64 = 0
        for address in Self.spendSources(in: discoveryResult) {
            confirmedSpendableSats = try safeAdd(
                confirmedSpendableSats,
                try await discovery.confirmedSpendableSats(
                    address: address.address,
                    network: network,
                    baseURL: baseURL
                )
            )
        }

        return BitcoinBalanceSyncResult(
            confirmedSats: confirmedSats,
            mempoolSats: mempoolSats,
            totalSats: try safeAdd(confirmedSats, mempoolSats),
            usedAddresses: discoveryResult.usedAddresses,
            discovery: discoveryResult,
            confirmedSpendableSats: confirmedSpendableSats
        )
    }

    /// Addresses holding value, largest first, capped at what one transfer may draw from.
    static func spendSources(in discovery: BitcoinReceiveDiscoveryResult) -> [BitcoinReceiveDiscoveredAddress] {
        Array(
            discovery.addresses
                .filter { $0.totalSats > 0 }
                .sorted { lhs, rhs in
                    if lhs.totalSats != rhs.totalSats {
                        return lhs.totalSats > rhs.totalSats
                    }
                    return lhs.path < rhs.path
                }
                .prefix(BitcoinSendPlanner.maxSources)
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
    /// Confirmed coins no mempool transaction spends. `totalSats` is what the wallet owns;
    /// this is the part a transfer can use now.
    let confirmedSpendableSats: Int64

    init(
        confirmedSats: Int64,
        mempoolSats: Int64,
        totalSats: Int64,
        usedAddresses: [BitcoinReceiveDiscoveredAddress],
        discovery: BitcoinReceiveDiscoveryResult,
        confirmedSpendableSats: Int64? = nil
    ) {
        self.confirmedSats = confirmedSats
        self.mempoolSats = mempoolSats
        self.totalSats = totalSats
        self.usedAddresses = usedAddresses
        self.discovery = discovery
        // Without coin detail the best bound is: confirmed, less anything the mempool spends.
        self.confirmedSpendableSats = confirmedSpendableSats ?? max(0, min(confirmedSats, totalSats))
    }

    /// Owned but not spendable yet: waiting for a confirmation.
    var pendingSats: Int64 {
        max(0, totalSats - confirmedSpendableSats)
    }
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
    /// A wallet scan is forty or more requests. Once a public indexer says "slow down" the
    /// next scan waits 2 minutes, then 4, 8, up to 15, instead of repeating the burst.
    static let initialRateLimitBackoff: TimeInterval = 120
    static let maxRateLimitBackoff: TimeInterval = 15 * 60

    private struct Entry {
        let value: BitcoinBalanceSyncResult
        let createdAt: Date
    }

    private struct Backoff {
        let consecutiveRateLimits: Int
        let retryAt: Date
        let error: Error
    }

    private let now: () -> Date
    private var entries: [Key: Entry] = [:]
    private var backoffs: [Key: Backoff] = [:]
    private var inFlight: [Key: Task<BitcoinBalanceSyncResult, Error>] = [:]

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// With `staleOnFailure`, a scan that fails or is being held back returns the last scan
    /// of this app session instead: enough for a transfer to know which addresses hold coins,
    /// since the planner reads their unspent outputs live anyway.
    func value(
        for key: Key,
        maxAge: TimeInterval = BitcoinWalletBalanceCache.defaultMaxAge,
        staleOnFailure: Bool = false,
        loader: @escaping () async throws -> BitcoinBalanceSyncResult
    ) async throws -> BitcoinBalanceSyncResult {
        if let entry = entries[key],
           now().timeIntervalSince(entry.createdAt) <= maxAge {
            return entry.value
        }

        if let backoff = backoffs[key], now() < backoff.retryAt {
            if staleOnFailure, let entry = entries[key] {
                return entry.value
            }
            throw backoff.error
        }

        let task: Task<BitcoinBalanceSyncResult, Error>
        if let running = inFlight[key] {
            task = running
        } else {
            task = Task {
                try await loader()
            }
            inFlight[key] = task
        }

        do {
            let result = try await task.value
            entries[key] = Entry(value: result, createdAt: now())
            backoffs[key] = nil
            inFlight[key] = nil
            return result
        } catch {
            inFlight[key] = nil
            if let retryAfter = Self.rateLimitRetryAfter(error) {
                let count = (backoffs[key]?.consecutiveRateLimits ?? 0) + 1
                let exponential = Self.initialRateLimitBackoff * pow(2, Double(min(count - 1, 10)))
                let delay = min(max(exponential, retryAfter), Self.maxRateLimitBackoff)
                backoffs[key] = Backoff(
                    consecutiveRateLimits: count,
                    retryAt: now().addingTimeInterval(delay),
                    error: error
                )
            }
            if staleOnFailure, !(error is CancellationError), let entry = entries[key] {
                return entry.value
            }
            throw error
        }
    }

    func invalidate(_ key: Key) {
        entries[key] = nil
    }

    /// A wallet that switched to the Bitcoin address its password protects scans another
    /// account; no scan of the old one may answer for it.
    func invalidate(walletId: MetaAccountId) {
        entries = entries.filter { $0.key.walletId != walletId }
    }

    /// Seconds the service asked for (zero if it named none), or `nil` when the failure is not
    /// a rate limit. Offline and server errors are retried on the next refresh as before.
    private static func rateLimitRetryAfter(_ error: Error) -> TimeInterval? {
        switch error {
        case let UniversalWalletHTTPTransportError.rateLimited(_, retryAfter):
            return retryAfter ?? 0
        case let BitcoinIndexerClientError.rateLimited(retryAfter):
            return retryAfter
        default:
            return nil
        }
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
