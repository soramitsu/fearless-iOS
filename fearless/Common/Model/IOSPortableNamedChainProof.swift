import Foundation
import IrohaCrypto

/// Checks the two iOS app-owned chains whose released signer is derived from
/// the wallet root. This does not verify other chain accounts or install data.
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

        var description: String { "IOSPortableNamedChainProof.Counts(<redacted>)" }
        var debugDescription: String { description }
    }

    static func verify(_ encoded: Data) throws -> Counts {
        var decoded: Codec.Snapshot
        do {
            decoded = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidNamedChainIdentity
        }
        defer { decoded.clearSecrets() }

        var bitcoinCount = 0
        var tairaCount = 0
        do {
            for wallet in decoded.wallets {
                var seen = Set<String>()
                for slot in wallet.slots where slot.role == Role.chainAccount {
                    let chainID = UniversalWalletChainAccountSupport.canonicalChainId(for: slot.key)
                    let category: String
                    switch chainID {
                    case UniversalWalletRegistry.bitcoinMainnet.chainId,
                         UniversalWalletRegistry.bitcoinTestnet.chainId:
                        category = chainID
                        try verifyBitcoin(slot, chainID: chainID, mnemonic: rootMnemonic(in: wallet))
                        bitcoinCount += 1
                    case UniversalWalletRegistry.taira.chainId:
                        category = chainID
                        try verifyTaira(slot, mnemonic: rootMnemonic(in: wallet))
                        tairaCount += 1
                    default:
                        continue
                    }
                    guard seen.insert(category).inserted else { throw ProofError.invalidNamedChainIdentity }
                }
            }
        } catch {
            throw ProofError.invalidNamedChainIdentity
        }
        return Counts(bitcoinAccounts: bitcoinCount, tairaAccounts: tairaCount)
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

    private static func verifyTaira(_ slot: Codec.Slot, mnemonic: String) throws {
        let derived = try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let publicKey = Data(try slot.value(FieldID.publicKey))
        let privateKey = Data(try slot.value(FieldID.privateKey))
        let accountID = Data(try slot.value(FieldID.accountIDOrAddress))
        guard try slot.number(FieldID.cryptoType) == 2,
              publicKey.count == 32,
              accountID == publicKey,
              privateKey == derived.privateKey,
              publicKey == derived.publicKey,
              try SolanaKeyDerivation.publicKey(fromPrivateKey: privateKey) == publicKey,
              UniversalWalletChainAccountSupport.address(
                  for: UniversalWalletRegistry.taira.chainId, publicKey: publicKey
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
