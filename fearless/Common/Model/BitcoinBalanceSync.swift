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
        let discoveryResult = try await discovery.discover(
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

enum BitcoinBalanceSyncError: Error, Equatable {
    case invalidAddressBalance
    case balanceOverflow
}
