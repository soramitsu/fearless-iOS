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

        let indexerNetwork = network.indexerNetwork
        var addresses: [BitcoinReceiveDiscoveredAddress] = []
        var consecutiveUnused = 0
        var index = 0
        var lastUsedIndex: Int?

        while consecutiveUnused < resolvedGapLimit, index < maxLookahead {
            let path = try BitcoinKeyDerivation.getReceivePath(network: network, index: UInt32(index))
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

        guard consecutiveUnused >= resolvedGapLimit else {
            throw BitcoinReceiveDiscoveryError.lookaheadExhausted
        }

        let nextReceiveIndex = (lastUsedIndex ?? -1) + 1
        let nextReceivePath = try BitcoinKeyDerivation.getReceivePath(network: network, index: UInt32(nextReceiveIndex))
        let nextReceiveAddress = try BitcoinKeyDerivation.deriveKey(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: nextReceivePath,
            network: network
        ).address

        return BitcoinReceiveDiscoveryResult(
            addresses: addresses,
            gapLimit: resolvedGapLimit,
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
