import Foundation
import IrohaCrypto

/// Checks named iOS chain keys and account identities. Bitcoin and Taira must
/// match their released root derivation; the other named chains may preserve
/// an independently imported key. This does not verify installer behavior.
enum IOSPortableNamedChainProof {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias Role = IOSPortableWalletSemanticMaterial.Role
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID

    enum ProofError: Error, Equatable {
        case invalidNamedChainIdentity
    }

    struct Counts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let bitcoinAccounts: Int
        let tairaAccounts: Int
        let solanaAccounts: Int
        let tonAccounts: Int
        let nexusAccounts: Int

        var description: String { "IOSPortableNamedChainProof.Counts(<redacted>)" }
        var debugDescription: String { description }
    }

    private enum ChainKind: Hashable {
        case bitcoin
        case taira
        case solana
        case ton
        case nexus
    }

    static func verify(_ encoded: Data) throws -> Counts {
        var decoded: Codec.Snapshot
        do {
            decoded = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidNamedChainIdentity
        }
        defer { decoded.clearSecrets() }

        var counts = [ChainKind: Int]()
        do {
            for wallet in decoded.wallets {
                var seen = Set<String>()
                for slot in wallet.slots where slot.role == Role.chainAccount {
                    let chainID = UniversalWalletChainAccountSupport.canonicalChainId(for: slot.key)
                    guard let kind = try verifyKnownChain(slot, chainID: chainID, wallet: wallet) else { continue }
                    guard seen.insert(chainID).inserted else { throw ProofError.invalidNamedChainIdentity }
                    counts[kind, default: 0] += 1
                }
            }
        } catch {
            throw ProofError.invalidNamedChainIdentity
        }
        return Counts(
            bitcoinAccounts: counts[.bitcoin, default: 0],
            tairaAccounts: counts[.taira, default: 0],
            solanaAccounts: counts[.solana, default: 0],
            tonAccounts: counts[.ton, default: 0],
            nexusAccounts: counts[.nexus, default: 0]
        )
    }

    private static func verifyKnownChain(
        _ slot: Codec.Slot, chainID: String, wallet: Codec.Wallet
    ) throws -> ChainKind? {
        switch chainID {
        case UniversalWalletRegistry.bitcoinMainnet.chainId,
             UniversalWalletRegistry.bitcoinTestnet.chainId:
            try verifyBitcoin(slot, chainID: chainID, mnemonic: rootMnemonic(in: wallet))
            return .bitcoin
        case UniversalWalletRegistry.taira.chainId:
            try verifyEd25519NamedChain(
                slot, chainID: chainID,
                derived: IrohaKeyDerivation.deriveAccount(mnemonic: rootMnemonic(in: wallet))
            )
            return .taira
        case UniversalWalletRegistry.solanaMainnet.chainId,
             UniversalWalletRegistry.solanaDevnet.chainId:
            // These networks can retain a separately imported scoped signer.
            // The format cannot claim root derivation here.
            try verifyEd25519NamedChain(slot, chainID: chainID)
            return .solana
        case UniversalWalletRegistry.tonMainnetRegistryEntry.chainId:
            try verifyEd25519NamedChain(slot, chainID: chainID)
            return .ton
        case UniversalWalletRegistry.nexus.chainId:
            try verifyEd25519NamedChain(slot, chainID: chainID)
            return .nexus
        default:
            return nil
        }
    }

    private static func verifyBitcoin(_ slot: Codec.Slot, chainID: String, mnemonic: String) throws {
        let network: BitcoinKeyDerivation.Network = chainID == UniversalWalletRegistry.bitcoinMainnet.chainId
            ? .mainnet : .testnet
        let derived = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: network)
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let privateKey = Data(try slot.value(FieldID.privateKey))
        let accountID = Data(try slot.value(FieldID.accountIDOrAddress))
        guard try slot.number(FieldID.cryptoType) == 3,
              publicKey.count == 33,
              accountID == publicKey,
              privateKey == derived.privateKey,
              publicKey == derived.publicKey,
              try BitcoinKeyDerivation.publicKey(fromPrivateKey: privateKey) == publicKey,
              UniversalWalletChainAccountSupport.address(for: chainID, publicKey: publicKey) != nil else {
            throw ProofError.invalidNamedChainIdentity
        }
    }

    private static func verifyEd25519NamedChain(
        _ slot: Codec.Slot, chainID: String, derived: IrohaDerivedAccount
    ) throws {
        try verifyEd25519NamedChain(
            slot, chainID: chainID,
            expectedPrivateKey: derived.privateKey, expectedPublicKey: derived.publicKey
        )
    }

    private static func verifyEd25519NamedChain(
        _ slot: Codec.Slot, chainID: String,
        expectedPrivateKey: Data? = nil, expectedPublicKey: Data? = nil
    ) throws {
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let privateKey = Data(try slot.value(FieldID.privateKey))
        let accountID = Data(try slot.value(FieldID.accountIDOrAddress))
        guard try slot.number(FieldID.cryptoType) == 2,
              publicKey.count == 32,
              accountID == publicKey,
              expectedPrivateKey == nil || privateKey == expectedPrivateKey,
              expectedPublicKey == nil || publicKey == expectedPublicKey,
              try SolanaKeyDerivation.publicKey(fromPrivateKey: privateKey) == publicKey,
              UniversalWalletChainAccountSupport.address(
                  for: chainID, publicKey: publicKey
              ) != nil else {
            throw ProofError.invalidNamedChainIdentity
        }
    }

    private static func rootMnemonic(in wallet: Codec.Wallet) throws -> String {
        guard let substrate = wallet.slots.first(where: { $0.role == Role.substrateRoot }) else {
            throw ProofError.invalidNamedChainIdentity
        }
        let entropy = substrate.fields.first(where: { $0.id == FieldID.entropy })?.value
        let bridges = try wallet.slots.filter { slot in
            guard slot.role == Role.auxiliarySource else { return false }
            return try slot.number(FieldID.sourcePlatform) == 2 &&
                slot.number(FieldID.sourceSlotRole) == 9
        }
        guard bridges.count <= 1 else { throw ProofError.invalidNamedChainIdentity }
        if let entropy {
            guard bridges.isEmpty else { throw ProofError.invalidNamedChainIdentity }
            return try IRMnemonicCreator().mnemonic(fromEntropy: Data(entropy)).toString()
        }
        guard let bridge = bridges.first,
              try bridge.number(FieldID.bindingKind) == 1,
              let source = String(bytes: try bridge.value(FieldID.sourceBytes), encoding: .utf8),
              source == UniversalWalletSeedBridge.contract,
              let walletSeed = substrate.fields.first(where: { $0.id == FieldID.seed })?.value else {
            throw ProofError.invalidNamedChainIdentity
        }
        return try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: Data(walletSeed))
    }
}
