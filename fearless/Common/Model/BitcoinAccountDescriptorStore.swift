import Foundation
import SSFModels

/// Public account descriptors that let balance refresh and fee quotes discover every Bitcoin
/// address of a wallet without reading its recovery phrase.
protocol BitcoinAccountDescriptorProviding {
    /// The descriptor of the Bitcoin account `wallet` shows on `chain`, only when the descriptor
    /// derives exactly that account's key and address.
    func descriptor(for wallet: MetaAccountModel, chain: ChainModel) -> BitcoinKeyDerivation.AccountDescriptor?
    /// True while the account has no descriptor yet but one can still be made at the next
    /// authorized unlock (its wallet's secret was not found to lack it).
    func isDescriptorPending(for wallet: MetaAccountModel, chain: ChainModel) -> Bool
}

extension BitcoinAccountDescriptorProviding {
    func isDescriptorPending(for _: MetaAccountModel, chain _: ChainModel) -> Bool {
        false
    }
}

/// Stores account descriptors per wallet and network, keyed by the account key they derive.
///
/// A descriptor holds no secret: it reveals the account's addresses, as the stored account rows
/// already do for the first one, and cannot sign. Every read checks that the descriptor's
/// `.../0/0` key equals the key the wallet stores for that network, so a stale or foreign
/// descriptor is ignored and refresh falls back to the single stored address.
final class BitcoinAccountDescriptorStore: BitcoinAccountDescriptorProviding {
    static let storageKey = "bitcoinAccountDescriptors.v1"
    static let shared = BitcoinAccountDescriptorStore()

    /// A wallet keeps a few accounts per network at most: the one it shows and, for a password
    /// wallet, the one the words open alone.
    private static let maxEntriesPerNetwork = 4
    private static let lock = NSLock()

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func descriptor(for wallet: MetaAccountModel, chain: ChainModel) -> BitcoinKeyDerivation.AccountDescriptor? {
        guard let slot = UniversalWalletSlot(chainId: chain.chainId),
              let network = slot.bitcoinNetwork,
              let account = slot.storedAccount(in: wallet),
              let descriptor = descriptor(walletId: wallet.metaId, network: network, accountPublicKey: account.publicKey)
        else {
            return nil
        }
        // The address refresh would otherwise read must be the descriptor's first address.
        guard let shown = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet),
              let derived = try? descriptor.address(change: 0, index: 0),
              shown.caseInsensitiveCompare(derived) == .orderedSame
        else {
            return nil
        }
        return descriptor
    }

    func isDescriptorPending(for wallet: MetaAccountModel, chain: ChainModel) -> Bool {
        guard let slot = UniversalWalletSlot(chainId: chain.chainId),
              let network = slot.bitcoinNetwork,
              let account = slot.storedAccount(in: wallet) else {
            return false
        }
        return !hasDescriptor(walletId: wallet.metaId, network: network, accountPublicKey: account.publicKey)
            && !isUnavailable(walletId: wallet.metaId, network: network, accountPublicKey: account.publicKey)
    }

    /// Records that no stored secret derives this account (the backfill looked and found none),
    /// so refresh stops waiting for a descriptor and reads the stored address alone.
    func markUnavailable(walletId: MetaAccountId, network: BitcoinKeyDerivation.Network, accountPublicKey: Data) {
        let marker = Self.unavailableMarker(network: network, accountPublicKey: accountPublicKey)
        update { stored in
            var entries = stored[walletId] ?? []
            if !entries.contains(marker) {
                entries.append(marker)
            }
            stored[walletId] = entries
        }
    }

    func isUnavailable(walletId: MetaAccountId, network: BitcoinKeyDerivation.Network, accountPublicKey: Data) -> Bool {
        let marker = Self.unavailableMarker(network: network, accountPublicKey: accountPublicKey)
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return (read()[walletId] ?? []).contains(marker)
    }

    private static func unavailableMarker(network: BitcoinKeyDerivation.Network, accountPublicKey: Data) -> String {
        ["none", network == .mainnet ? "mainnet" : "testnet", accountPublicKey.toHex()].joined(separator: "|")
    }

    /// The stored descriptor whose first receive key is `accountPublicKey`.
    func descriptor(
        walletId: MetaAccountId,
        network: BitcoinKeyDerivation.Network,
        accountPublicKey: Data
    ) -> BitcoinKeyDerivation.AccountDescriptor? {
        entries(walletId: walletId).first { entry in
            entry.network == network && entry.accountPublicKey == accountPublicKey
        }.flatMap { entry in
            guard let descriptor = try? BitcoinKeyDerivation.AccountDescriptor(
                network: entry.network,
                publicKey: entry.publicKey,
                chainCode: entry.chainCode
            ), (try? descriptor.firstReceivePublicKey()) == accountPublicKey else {
                return nil
            }
            return descriptor
        }
    }

    func hasDescriptor(
        walletId: MetaAccountId,
        network: BitcoinKeyDerivation.Network,
        accountPublicKey: Data
    ) -> Bool {
        descriptor(walletId: walletId, network: network, accountPublicKey: accountPublicKey) != nil
    }

    /// Saves `descriptor` for `walletId`. It is keyed by the account key it derives, so a later
    /// save for the same account replaces it.
    func save(_ descriptor: BitcoinKeyDerivation.AccountDescriptor, walletId: MetaAccountId) throws {
        let entry = Entry(
            network: descriptor.network,
            accountPublicKey: try descriptor.firstReceivePublicKey(),
            publicKey: descriptor.publicKey,
            chainCode: descriptor.chainCode
        )
        let marker = Self.unavailableMarker(network: entry.network, accountPublicKey: entry.accountPublicKey)
        update { stored in
            let raw = stored[walletId] ?? []
            var entries = raw.compactMap(Entry.init(encoded:))
            // Markers for other accounts stay; this account now has a descriptor.
            let markers = raw.filter { Entry(encoded: $0) == nil && $0 != marker }
            entries.removeAll { $0.network == entry.network && $0.accountPublicKey == entry.accountPublicKey }
            entries.append(entry)
            let sameNetwork = entries.filter { $0.network == entry.network }
            if sameNetwork.count > Self.maxEntriesPerNetwork,
               let oldest = sameNetwork.first {
                entries.removeAll { $0 == oldest }
            }
            stored[walletId] = entries.map(\.encoded) + markers
        }
    }

    /// The only way an entry goes: the wallet itself is removed.
    func forget(walletId: MetaAccountId) {
        update { $0[walletId] = nil }
    }

    private func entries(walletId: MetaAccountId) -> [Entry] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return (read()[walletId] ?? []).compactMap(Entry.init(encoded:))
    }

    private func read() -> [String: [String]] {
        (userDefaults.dictionary(forKey: Self.storageKey) as? [String: [String]]) ?? [:]
    }

    private func update(_ change: (inout [String: [String]]) -> Void) {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        var value = read()
        change(&value)
        userDefaults.set(value, forKey: Self.storageKey)
    }
}

private extension BitcoinAccountDescriptorStore {
    struct Entry: Equatable {
        let network: BitcoinKeyDerivation.Network
        let accountPublicKey: Data
        let publicKey: Data
        let chainCode: Data

        /// `v1|<mainnet|testnet>|<account key>|<node key>|<chain code>`, hex.
        var encoded: String {
            ["v1", network == .mainnet ? "mainnet" : "testnet", accountPublicKey.toHex(), publicKey.toHex(), chainCode.toHex()]
                .joined(separator: "|")
        }

        init(
            network: BitcoinKeyDerivation.Network,
            accountPublicKey: Data,
            publicKey: Data,
            chainCode: Data
        ) {
            self.network = network
            self.accountPublicKey = accountPublicKey
            self.publicKey = publicKey
            self.chainCode = chainCode
        }

        init?(encoded: String) {
            let parts = encoded.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 5, parts[0] == "v1",
                  let accountPublicKey = try? Data(hexStringSSF: parts[2]),
                  let publicKey = try? Data(hexStringSSF: parts[3]),
                  let chainCode = try? Data(hexStringSSF: parts[4])
            else {
                return nil
            }
            switch parts[1] {
            case "mainnet":
                network = .mainnet
            case "testnet":
                network = .testnet
            default:
                return nil
            }
            self.accountPublicKey = accountPublicKey
            self.publicKey = publicKey
            self.chainCode = chainCode
        }
    }
}

extension UniversalWalletSlot {
    /// The Bitcoin network of a Bitcoin slot.
    var bitcoinNetwork: BitcoinKeyDerivation.Network? {
        switch self {
        case .bitcoinMainnet:
            return .mainnet
        case .bitcoinTestnet:
            return .testnet
        case .solana, .ton, .taira:
            return nil
        }
    }
}
