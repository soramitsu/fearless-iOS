import Foundation
import SSFModels

enum UniversalWalletAccountAddressResolver {
    static func address(for chain: ChainModel, wallet: MetaAccountModel) -> AccountAddress? {
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

    static func chainId(_ storedChainId: String, matches requestedChainId: String) -> Bool {
        guard let equivalentIds = equivalentChainIds(for: requestedChainId) else {
            return storedChainId == requestedChainId
        }

        return equivalentIds.contains(storedChainId.lowercased())
    }

    static func address(for chainId: String, publicKey: Data) -> AccountAddress? {
        switch chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return bitcoinAddress(fromPublicKey: publicKey, network: .mainnet)
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return bitcoinAddress(fromPublicKey: publicKey, network: .testnet)
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id,
             UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return solanaAddress(fromPublicKey: publicKey)
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.taira.id:
            return irohaAddress(
                fromPublicKey: publicKey,
                chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
        case UniversalWalletRegistry.nexus.chainId, UniversalWalletRegistry.nexus.id:
            return irohaAddress(
                fromPublicKey: publicKey,
                chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            )
        default:
            return nil
        }
    }

    private static func equivalentChainIds(for chainId: String) -> Set<String>? {
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
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.taira.id:
            return [
                UniversalWalletRegistry.taira.chainId,
                UniversalWalletRegistry.taira.id
            ]
        case UniversalWalletRegistry.nexus.chainId, UniversalWalletRegistry.nexus.id:
            return [
                UniversalWalletRegistry.nexus.chainId,
                UniversalWalletRegistry.nexus.id
            ]
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
