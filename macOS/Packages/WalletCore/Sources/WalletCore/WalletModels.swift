import Foundation

public enum CryptoType: String, Codable, Sendable, CaseIterable, Hashable {
    case sr25519
    case ed25519
    case ecdsa

    public var displayName: String {
        switch self {
        case .sr25519: return "Schnorrkel (sr25519, recommended)"
        case .ed25519: return "Edwards (ed25519)"
        case .ecdsa: return "ECDSA (secp256k1)"
        }
    }
}

/// How a wallet came to exist on this Mac.
public enum WalletOrigin: String, Codable, Sendable, Hashable {
    case created
    case mnemonic
    case seed
    case json
    case watchOnly

    public var displayName: String {
        switch self {
        case .created: return "Created on this Mac"
        case .mnemonic: return "Imported from recovery phrase"
        case .seed: return "Imported from raw seed"
        case .json: return "Imported from JSON backup"
        case .watchOnly: return "Watch-only"
        }
    }
}

/// One signing account of a wallet. A wallet usually has one Substrate and
/// one EVM account.
public struct WalletAccount: Hashable, Codable, Sendable {
    public var ecosystem: Ecosystem
    public var cryptoType: CryptoType
    /// Substrate: the account public key (32 bytes, 33 for ECDSA).
    /// EVM: the 20-byte account address.
    public var publicKey: Data
    public var derivationPath: String?

    public init(ecosystem: Ecosystem, cryptoType: CryptoType, publicKey: Data, derivationPath: String?) {
        self.ecosystem = ecosystem
        self.cryptoType = cryptoType
        self.publicKey = publicKey
        self.derivationPath = derivationPath
    }
}

public struct Wallet: Identifiable, Hashable, Codable, Sendable {
    public var id: WalletID
    public var name: String
    public var origin: WalletOrigin
    public var accounts: [WalletAccount]
    public var createdAt: Date
    /// False until the user confirmed the recovery phrase backup.
    public var isBackedUp: Bool

    public init(
        id: WalletID = WalletID(),
        name: String,
        origin: WalletOrigin,
        accounts: [WalletAccount],
        createdAt: Date = Date(),
        isBackedUp: Bool
    ) {
        self.id = id
        self.name = name
        self.origin = origin
        self.accounts = accounts
        self.createdAt = createdAt
        self.isBackedUp = isBackedUp
    }

    public var isWatchOnly: Bool { origin == .watchOnly }

    /// True when the wallet holds a recovery phrase that can be exported.
    public var hasRecoveryPhrase: Bool { origin == .created || origin == .mnemonic }

    public var ecosystems: Set<Ecosystem> { Set(accounts.map(\.ecosystem)) }

    public func account(for ecosystem: Ecosystem) -> WalletAccount? {
        accounts.first { $0.ecosystem == ecosystem }
    }
}

public enum MnemonicLength: Int, Codable, Sendable, CaseIterable, Hashable {
    case words12 = 12
    case words15 = 15
    case words18 = 18
    case words21 = 21
    case words24 = 24
}

public enum MnemonicValidation: Hashable, Sendable {
    case valid
    case invalidLength(count: Int)
    /// Index (0-based) of each word that is not in the BIP-39 English list.
    case unknownWords(indices: [Int])
    case invalidChecksum
}

/// Key derivation choices for an import. The defaults match the Fearless
/// iOS and Android apps, so the same phrase gives the same addresses.
public struct DerivationOptions: Hashable, Codable, Sendable {
    public var substrateCryptoType: CryptoType
    /// Substrate derivation path such as `//polkadot` or `//hard/soft///password`; empty for none.
    public var substrateDerivationPath: String
    /// BIP-44 path for the EVM account.
    public var evmDerivationPath: String

    public init(
        substrateCryptoType: CryptoType = .sr25519,
        substrateDerivationPath: String = "",
        evmDerivationPath: String = DerivationOptions.defaultEVMPath
    ) {
        self.substrateCryptoType = substrateCryptoType
        self.substrateDerivationPath = substrateDerivationPath
        self.evmDerivationPath = evmDerivationPath
    }

    public static let defaultEVMPath = "m/44'/60'/0'/0/0"
    public static let standard = DerivationOptions()
}

public enum WalletImportSource: Sendable, Hashable {
    /// New or existing BIP-39 phrase; gives a Substrate and an EVM account.
    case mnemonic(words: [String], options: DerivationOptions)
    /// Raw 32-byte seed (Substrate) or private key (EVM), hex with or without `0x`.
    case seed(hex: String, ecosystem: Ecosystem, options: DerivationOptions)
    /// Polkadot.js / Fearless JSON keystore with its password.
    case json(data: Data, password: String)
    /// Addresses only; cannot sign.
    case watchOnly(substrateAddress: String?, evmAddress: String?)
}

/// Addresses a source would produce, shown before the user commits an import.
public struct WalletAddressPreview: Hashable, Sendable {
    /// Substrate address formatted for Polkadot (SS58 prefix 0).
    public var substrate: String?
    /// EIP-55 checksummed EVM address.
    public var evm: String?

    public init(substrate: String?, evm: String?) {
        self.substrate = substrate
        self.evm = evm
    }
}
