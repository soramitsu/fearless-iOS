import Foundation
import SSFModels

enum UniversalWalletAccountAddressResolver {
    static func address(for chain: ChainModel, wallet: MetaAccountModel) -> AccountAddress? {
        if UniversalWalletChainAccountSupport.isNonCanonicalIrohaProfile(chain) {
            return nil
        }

        if UniversalWalletChainAccountSupport.isUniversalWalletChain(chain.chainId) {
            guard let account = wallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chain.chainId)
            }) else {
                return nil
            }

            return UniversalWalletChainAccountSupport.address(
                for: chain.chainId,
                publicKey: account.publicKey
            )
        } else {
            return wallet.fetch(for: chain.accountRequest())?.toAddress()
        }
    }
}

enum UniversalWalletChainAccountSupport {
    static func isUniversalWalletChain(_ chainId: String) -> Bool {
        equivalentChainIds(for: chainId) != nil
    }

    static func isNonCanonicalIrohaIdentity(_ chainId: String) -> Bool {
        guard exactIrohaNetwork(for: chainId) == nil else {
            return false
        }

        let trimmedChainId = chainId.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.taira.id) == .orderedSame ||
            trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.nexus.id) == .orderedSame ||
            trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.taira.chainId) == .orderedSame ||
            trimmedChainId.caseInsensitiveCompare(UniversalWalletRegistry.nexus.chainId) == .orderedSame ||
            trimmedChainId.caseInsensitiveCompare("iroha3-taira") == .orderedSame
    }

    static func isNonCanonicalIrohaProfile(_ chain: ChainModel) -> Bool {
        guard exactIrohaNetwork(for: chain.chainId) == nil else {
            return false
        }

        return isNonCanonicalIrohaIdentity(chain.chainId) ||
            chain.chainAssets.contains {
                $0.asset.id == UniversalWalletRegistry.tairaXorAssetDefinitionId
            }
    }

    /// Returns the stable storage identity for a universal-wallet chain alias.
    ///
    /// Non-universal chain identifiers are intentionally returned unchanged: their
    /// alias semantics belong to the remote chain registry and must not be guessed.
    static func canonicalChainId(for chainId: String) -> String {
        if let network = exactIrohaNetwork(for: chainId) {
            return network.chainId
        }

        switch chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return UniversalWalletRegistry.bitcoinMainnet.chainId
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return UniversalWalletRegistry.bitcoinTestnet.chainId
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id:
            return UniversalWalletRegistry.solanaMainnet.chainId
        case UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return UniversalWalletRegistry.solanaDevnet.chainId
        case TonChainSelection.mainnetChainId,
             UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
             UniversalWalletRegistry.tonMainnetRegistryEntry.id:
            return UniversalWalletRegistry.tonMainnetRegistryEntry.chainId
        default:
            return chainId
        }
    }

    static func chainId(_ storedChainId: String, matches requestedChainId: String) -> Bool {
        guard let equivalentIds = equivalentChainIds(for: requestedChainId) else {
            return storedChainId == requestedChainId
        }

        if exactIrohaNetwork(for: requestedChainId) != nil {
            return storedChainId == requestedChainId
        }

        return equivalentIds.contains(storedChainId.lowercased())
    }

    static func address(for chainId: String, publicKey: Data) -> AccountAddress? {
        if let network = exactIrohaNetwork(for: chainId) {
            return irohaAddress(
                fromPublicKey: publicKey,
                chainDiscriminant: network.chainDiscriminant
            )
        }

        switch chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return bitcoinAddress(fromPublicKey: publicKey, network: .mainnet)
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return bitcoinAddress(fromPublicKey: publicKey, network: .testnet)
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id,
             UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return solanaAddress(fromPublicKey: publicKey)
        case TonChainSelection.mainnetChainId,
             UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
             UniversalWalletRegistry.tonMainnetRegistryEntry.id:
            return tonAddress(fromPublicKey: publicKey)
        default:
            return nil
        }
    }

    private static func equivalentChainIds(for chainId: String) -> Set<String>? {
        if let network = exactIrohaNetwork(for: chainId) {
            return [network.chainId]
        }

        switch chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return [
                UniversalWalletRegistry.bitcoinMainnet.chainId,
                UniversalWalletRegistry.bitcoinMainnet.id
            ]
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return [
                UniversalWalletRegistry.bitcoinTestnet.chainId,
                UniversalWalletRegistry.bitcoinTestnet.id
            ]
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id:
            return [
                UniversalWalletRegistry.solanaMainnet.chainId,
                UniversalWalletRegistry.solanaMainnet.id
            ]
        case UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return [
                UniversalWalletRegistry.solanaDevnet.chainId,
                UniversalWalletRegistry.solanaDevnet.id
            ]
        case TonChainSelection.mainnetChainId,
             UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
             UniversalWalletRegistry.tonMainnetRegistryEntry.id:
            return [
                TonChainSelection.mainnetChainId,
                UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
                UniversalWalletRegistry.tonMainnetRegistryEntry.id
            ]
        default:
            return nil
        }
    }

    private static func exactIrohaNetwork(
        for chainId: String
    ) -> UniversalWalletRegistry.IrohaNetwork? {
        switch chainId {
        case UniversalWalletRegistry.taira.chainId:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId:
            return UniversalWalletRegistry.nexus
        default:
            return nil
        }
    }

    private static func bitcoinAddress(
        fromPublicKey publicKey: Data,
        network: BitcoinKeyDerivation.Network
    ) -> AccountAddress? {
        let indexerNetwork: BitcoinIndexerNetwork = network == .mainnet ? .mainnet : .testnet

        guard
            let address = try? BitcoinKeyDerivation.address(fromPublicKey: publicKey, network: network),
            let normalizedAddress = try? BitcoinIndexerRoutes.normalizeAddress(address, network: indexerNetwork)
        else {
            return nil
        }

        return normalizedAddress
    }

    private static func solanaAddress(fromPublicKey publicKey: Data) -> AccountAddress? {
        guard
            let address = try? SolanaKeyDerivation.address(fromPublicKey: publicKey),
            (try? SolanaIndexerRoutes.balancesURL(wallet: address)) != nil
        else {
            return nil
        }

        return address
    }

    private static func tonAddress(fromPublicKey publicKey: Data) -> AccountAddress? {
        try? TonAddressCodec.v4R2Addresses(publicKey: publicKey).nonBounceable
    }

    private static func irohaAddress(
        fromPublicKey publicKey: Data,
        chainDiscriminant: Int
    ) -> AccountAddress? {
        let publicKeyHex = publicKey.map { String(format: "%02x", $0) }.joined()
        guard
            let address = try? IrohaAddressCodec.encode(
                publicKeyHex: publicKeyHex,
                chainDiscriminant: chainDiscriminant
            ),
            (try? IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: chainDiscriminant
            )) != nil
        else {
            return nil
        }

        return address
    }
}
