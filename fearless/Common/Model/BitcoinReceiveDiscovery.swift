import Foundation

final class BitcoinReceiveDiscovery {
    static let defaultMaxLookahead = 1000
    static let maxGapLimit = 100
    static let maxLookahead = 10000

    private let client: BitcoinIndexerClientProtocol

    init(client: BitcoinIndexerClientProtocol) {
        self.client = client
    }

    func discover(
        mnemonic: String,
        passphrase: String = "",
        network: BitcoinKeyDerivation.Network = .mainnet,
        baseURL: String? = nil,
        gapLimit: Int? = nil,
        maxLookahead: Int = BitcoinReceiveDiscovery.defaultMaxLookahead
    ) async throws -> BitcoinReceiveDiscoveryResult {
        let resolvedGapLimit = gapLimit ?? Self.defaultGapLimit(for: network)
        try validateParams(mnemonic: mnemonic, gapLimit: resolvedGapLimit, maxLookahead: maxLookahead)

        return try await discoverBranch(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            baseURL: baseURL,
            gapLimit: resolvedGapLimit,
            maxLookahead: maxLookahead,
            change: 0
        )
    }

    func discoverWallet(
        mnemonic: String,
        passphrase: String = "",
        network: BitcoinKeyDerivation.Network = .mainnet,
        baseURL: String? = nil,
        gapLimit: Int? = nil,
        maxLookahead: Int = BitcoinReceiveDiscovery.defaultMaxLookahead
    ) async throws -> BitcoinReceiveDiscoveryResult {
        let resolvedGapLimit = gapLimit ?? Self.defaultGapLimit(for: network)
        try validateParams(mnemonic: mnemonic, gapLimit: resolvedGapLimit, maxLookahead: maxLookahead)

        let receive = try await discoverBranch(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            baseURL: baseURL,
            gapLimit: resolvedGapLimit,
            maxLookahead: maxLookahead,
            change: 0
        )
        let change = try await discoverBranch(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: network,
            baseURL: baseURL,
            gapLimit: resolvedGapLimit,
            maxLookahead: maxLookahead,
            change: 1
        )

        return BitcoinReceiveDiscoveryResult(
            addresses: receive.addresses + change.addresses,
            gapLimit: resolvedGapLimit,
            lastUsedIndex: receive.lastUsedIndex,
            nextReceiveAddress: receive.nextReceiveAddress,
            nextReceiveIndex: receive.nextReceiveIndex,
            usedAddresses: receive.usedAddresses + change.usedAddresses
        )
    }

    func balance(
        address: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String? = nil
    ) async throws -> BitcoinAddressBalanceResult {
        let stats = try await client.address(
            address: address,
            network: network.indexerNetwork,
            baseURL: baseURL
        )
        _ = try transactionCount(stats)

        guard stats.confirmedSats >= 0, stats.totalSats >= 0 else {
            throw BitcoinBalanceSyncError.invalidAddressBalance
        }

        return BitcoinAddressBalanceResult(
            confirmedSats: stats.confirmedSats,
            mempoolSats: stats.mempoolSats,
            totalSats: stats.totalSats
        )
    }

    private func discoverBranch(
        mnemonic: String,
        passphrase: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String?,
        gapLimit: Int,
        maxLookahead: Int,
        change: UInt32
    ) async throws -> BitcoinReceiveDiscoveryResult {
        let indexerNetwork = network.indexerNetwork
        var addresses: [BitcoinReceiveDiscoveredAddress] = []
        var consecutiveUnused = 0
        var index = 0
        var lastUsedIndex: Int?

        while consecutiveUnused < gapLimit, index < maxLookahead {
            try Task.checkCancellation()
            let path = try BitcoinKeyDerivation.getReceivePath(
                network: network,
                index: UInt32(index),
                change: change
            )
            let address = try BitcoinKeyDerivation.deriveKey(
                mnemonic: mnemonic,
                passphrase: passphrase,
                derivationPath: path,
                network: network
            ).address
            let stats = try await client.address(address: address, network: indexerNetwork, baseURL: baseURL)
            let txCount = try transactionCount(stats)
            let used = txCount > 0
            let discovered = BitcoinReceiveDiscoveredAddress(
                address: address,
                index: index,
                path: path,
                confirmedSats: stats.confirmedSats,
                mempoolSats: stats.mempoolSats,
                totalSats: stats.totalSats,
                txCount: txCount,
                used: used
            )

            addresses.append(discovered)

            if used {
                lastUsedIndex = index
                consecutiveUnused = 0
            } else {
                consecutiveUnused += 1
            }

            index += 1
        }

        guard consecutiveUnused >= gapLimit else {
            throw BitcoinReceiveDiscoveryError.lookaheadExhausted
        }

        let nextReceiveIndex = (lastUsedIndex ?? -1) + 1
        let nextReceivePath = try BitcoinKeyDerivation.getReceivePath(
            network: network,
            index: UInt32(nextReceiveIndex),
            change: change
        )
        let nextReceiveAddress = try BitcoinKeyDerivation.deriveKey(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: nextReceivePath,
            network: network
        ).address

        return BitcoinReceiveDiscoveryResult(
            addresses: addresses,
            gapLimit: gapLimit,
            lastUsedIndex: lastUsedIndex,
            nextReceiveAddress: nextReceiveAddress,
            nextReceiveIndex: nextReceiveIndex,
            usedAddresses: addresses.filter(\.used)
        )
    }

    private func validateParams(mnemonic: String, gapLimit: Int, maxLookahead: Int) throws {
        guard !mnemonic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BitcoinReceiveDiscoveryError.mnemonicRequired
        }
        guard gapLimit > 0, gapLimit <= Self.maxGapLimit else {
            throw BitcoinReceiveDiscoveryError.invalidGapLimit
        }
        guard maxLookahead >= gapLimit, maxLookahead <= Self.maxLookahead else {
            throw BitcoinReceiveDiscoveryError.invalidMaxLookahead
        }
    }

    private func transactionCount(_ address: BitcoinEsploraAddress) throws -> Int {
        guard address.chainStats.txCount >= 0, address.mempoolStats.txCount >= 0 else {
            throw BitcoinReceiveDiscoveryError.invalidTransactionCount
        }

        let total = address.chainStats.txCount.addingReportingOverflow(address.mempoolStats.txCount)
        guard !total.overflow, total.partialValue >= 0 else {
            throw BitcoinReceiveDiscoveryError.invalidTransactionCount
        }

        return total.partialValue
    }

    private static func defaultGapLimit(for network: BitcoinKeyDerivation.Network) -> Int {
        switch network {
        case .mainnet:
            return UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit
        case .testnet:
            return UniversalWalletRegistry.bitcoinTestnet.defaultGapLimit
        }
    }
}

struct BitcoinReceiveDiscoveredAddress: Equatable {
    let address: String
    let index: Int
    let path: String
    let confirmedSats: Int64
    let mempoolSats: Int64
    let totalSats: Int64
    let txCount: Int
    let used: Bool
}

struct BitcoinReceiveDiscoveryResult: Equatable {
    let addresses: [BitcoinReceiveDiscoveredAddress]
    let gapLimit: Int
    let lastUsedIndex: Int?
    let nextReceiveAddress: String
    let nextReceiveIndex: Int
    let usedAddresses: [BitcoinReceiveDiscoveredAddress]
}

enum BitcoinReceiveDiscoveryError: Error, Equatable {
    case mnemonicRequired
    case invalidGapLimit
    case invalidMaxLookahead
    case invalidTransactionCount
    case lookaheadExhausted
}

private extension BitcoinKeyDerivation.Network {
    var indexerNetwork: BitcoinIndexerNetwork {
        switch self {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        }
    }
}
