import Foundation
import IrohaCrypto
import SSFCrypto
import SSFKeyPair
import SSFModels
import SSFSigner
import SSFUtils
import WalletCore
import struct Web3.EthereumAddress

extension WalletCore.CryptoType {
    var native: SSFModels.CryptoType {
        switch self {
        case .sr25519: return .sr25519
        case .ed25519: return .ed25519
        case .ecdsa: return .ecdsa
        }
    }
}

/// The vault owns this record. In particular, derivation paths can contain a password.
struct WalletSecret: Codable {
    var entropy: Data?
    fileprivate var rawSeed: Data?
    fileprivate var keys: [Key]

    fileprivate struct Key: Codable {
        let ecosystem: Ecosystem
        let type: WalletCore.CryptoType
        let path: String?
        let publicKey: Data
        let secretKey: Data

        func account() throws -> WalletAccount {
            let identifier = ecosystem == .evm ? try publicKey.ethereumAddressFromPublicKey() : publicKey
            let publicPath = path.map { String($0[..<($0.range(of: "///")?.lowerBound ?? $0.endIndex)]) }
            return WalletAccount(
                ecosystem: ecosystem, cryptoType: type, publicKey: identifier,
                derivationPath: publicPath?.isEmpty == false ? publicPath : nil
            )
        }
    }

    func accounts() throws -> [WalletAccount] {
        try keys.map { try $0.account() }
    }

    func mnemonicBackup() throws -> MnemonicBackup {
        guard let entropy,
              let substrate = keys.first(where: { $0.ecosystem == .substrate }),
              let evm = keys.first(where: { $0.ecosystem == .evm }), let evmPath = evm.path else {
            throw WalletError.invalidMnemonic
        }
        return try MnemonicBackup(
            words: IRMnemonicCreator().mnemonic(fromEntropy: entropy).allWords(),
            options: DerivationOptions(
                substrateCryptoType: substrate.type, substrateDerivationPath: substrate.path ?? "",
                evmDerivationPath: evmPath
            )
        )
    }

    func exportJSON(ecosystem: Ecosystem, name: String, password: String) throws -> Data {
        guard PasswordPolicy.isAcceptable(password) else { throw WalletError.passwordTooWeak }
        guard let key = keys.first(where: { $0.ecosystem == ecosystem }) else { throw WalletError.unsupportedChain }
        let address = try WalletKeys.address(key.account(), prefix: 42)
        // Polkadot.js writes the NaCl Ed25519 secret as seed || public key.
        let exportedSecret = key.type == .ed25519 ? key.secretKey + key.publicKey : key.secretKey
        let data = KeystoreData(
            address: address,
            secretKeyData: exportedSecret,
            publicKeyData: key.publicKey,
            cryptoType: key.type.native
        )
        let json = try KeystoreBuilder().with(name: name).build(
            from: data,
            password: password,
            isEthereum: ecosystem == .evm
        )
        return try JSONEncoder().encode(json)
    }

    /// For EVM, pass the unsigned RLP envelope including any transaction type byte.
    /// For Substrate, the extrinsic encoder owns the >256-byte payload rule.
    func sign(_ payload: Data, ecosystem: Ecosystem) throws -> Data {
        guard let key = keys.first(where: { $0.ecosystem == ecosystem }) else { throw WalletError.unsupportedChain }
        if ecosystem == .substrate, key.type == .ecdsa {
            // Match fearless/Common/Crypto/SigningWrapperProtocol.signEcdsa exactly.
            let privateKey = try SECPrivateKey(rawData: key.secretKey)
            return try SECSigner(privateKey: privateKey).sign(payload.blake2b32()).rawData()
        }
        let signer = TransactionSignerAssembly.signer(
            for: ecosystem == .evm ? .ethereum : .substrate,
            publicKeyData: key.publicKey,
            secretKeyData: key.secretKey,
            cryptoType: key.type.native
        )
        return try signer.sign(payload).rawData()
    }
}

enum WalletKeys {
    typealias Imported = (accounts: [WalletAccount], secret: WalletSecret?, origin: WalletOrigin)
    private typealias Key = WalletSecret.Key

    static func importSource(_ source: WalletImportSource) throws -> Imported {
        do { return try resolve(source) }
        catch let error as WalletError { throw error }
        catch {
            switch source {
            case .watchOnly: throw WalletError.invalidAddress("Enter a valid account address.")
            case .seed: throw WalletError.invalidSeed
            case .mnemonic, .created: throw WalletError.unknown("The derivation path is invalid for this signing scheme.")
            case .json: throw WalletError.invalidJSON("Invalid key or unsupported backup format.")
            }
        }
    }

    private static func resolve(_ source: WalletImportSource) throws -> Imported {
        switch source {
        case let .created(words, options):
            let restored = try resolve(.mnemonic(words: words, options: options))
            return (restored.accounts, restored.secret, .created)
        case let .mnemonic(words, options):
            let phrase = words.joined(separator: " ")
            guard MnemonicLength(rawValue: words.count) != nil,
                  let mnemonic = try? MnemonicCreatorImpl().mnemonic(fromList: phrase) else {
                throw WalletError.invalidMnemonic
            }
            let path = options.substrateDerivationPath
            let substrateJunctions = try junctions(path, ethereum: false)
            let subSeed = try SeedFactory().deriveSeed(from: phrase, password: substrateJunctions.password ?? "").seed
                .miniSeed
            let substrate = try substrateKey(
                seed: subSeed,
                type: options.substrateCryptoType,
                junctions: substrateJunctions,
                path: path
            )
            let evmJunctions = try junctions(options.evmDerivationPath, ethereum: true)
            let evmSeed = try BIP32SeedFactory().deriveSeed(from: phrase, password: evmJunctions.password ?? "").seed
            let ethPair = try BIP32KeypairFactory().createKeypairFromSeed(
                evmSeed,
                chaincodeList: evmJunctions.chaincodes
            )
            let ethereum = Key(
                ecosystem: .evm,
                type: .ecdsa,
                path: options.evmDerivationPath,
                publicKey: ethPair.publicKey().rawData(),
                secretKey: ethPair.privateKey().rawData()
            )
            return try imported(keys: [substrate, ethereum], entropy: mnemonic.entropy(), origin: .mnemonic)
        case let .seed(hex, ecosystem, options):
            guard let seed = strictHex(hex, bytes: 32) else { throw WalletError.invalidSeed }
            let key: Key
            if ecosystem == .evm {
                let pair = try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: seed))
                key = Key(
                    ecosystem: .evm,
                    type: .ecdsa,
                    path: nil,
                    publicKey: pair.publicKey().rawData(),
                    secretKey: seed
                )
            } else {
                let path = options.substrateDerivationPath
                key = try substrateKey(
                    seed: seed,
                    type: options.substrateCryptoType,
                    junctions: junctions(path, ethereum: false),
                    path: path
                )
            }
            return try imported(keys: [key], rawSeed: seed, origin: .seed)
        case let .json(data, password):
            return try imported(keys: [readJSON(data, password: password)], origin: .json)
        case let .watchOnly(substrate, evm):
            var accounts: [WalletAccount] = []
            if let substrate {
                let decoded = try decodeSS58(substrate)
                // An SS58 address encodes an account id. Its signing scheme is undisclosed.
                accounts.append(WalletAccount(
                    ecosystem: .substrate,
                    cryptoType: .sr25519,
                    publicKey: decoded.id,
                    derivationPath: nil
                ))
            }
            if let evm {
                let identifier = try decodeEthereum(evm)
                accounts.append(WalletAccount(
                    ecosystem: .evm,
                    cryptoType: .ecdsa,
                    publicKey: identifier,
                    derivationPath: nil
                ))
            }
            guard !accounts.isEmpty else { throw WalletError.invalidAddress("Enter at least one address.") }
            return (accounts, nil, .watchOnly)
        }
    }

    private static func imported(
        keys: [Key],
        entropy: Data? = nil,
        rawSeed: Data? = nil,
        origin: WalletOrigin
    ) throws -> Imported {
        let secret = WalletSecret(entropy: entropy, rawSeed: rawSeed, keys: keys)
        return try (secret.accounts(), secret, origin)
    }

    private static func junctions(_ path: String, ethereum: Bool) throws -> JunctionResult {
        var nativePath = path
        if ethereum, path == "m" {
            nativePath = ""
        }
        if ethereum, path.hasPrefix("m/") {
            let suffix = path.range(of: "///")?.lowerBound ?? path.endIndex
            let bip32 = path[..<suffix]
            let components = bip32 == "m" ? [] : bip32.dropFirst(2).split(
                separator: "/",
                omittingEmptySubsequences: false
            )
            var translated = ""
            for component in components {
                let hardened = component.last == "'"
                let digits = hardened ? component.dropLast() : component[...]
                guard !digits.isEmpty, digits.utf8.allSatisfy({ (48 ... 57).contains($0) }) else {
                    throw WalletError.invalidSeed
                }
                translated += (hardened ? "//" : "/") + digits
            }
            nativePath = translated + path[suffix...]
        }
        if nativePath.isEmpty {
            return JunctionResult(chaincodes: [], password: nil)
        }
        let factory: JunctionFactory = ethereum ? BIP32JunctionFactory() : SubstrateJunctionFactory()
        return try factory.parse(path: nativePath)
    }

    private static func substrateKey(
        seed: Data,
        type: WalletCore.CryptoType,
        junctions: JunctionResult,
        path: String?
    ) throws -> Key {
        let factory: KeypairFactoryProtocol
        switch type {
        case .sr25519: factory = SR25519KeypairFactory()
        case .ed25519: factory = Ed25519KeypairFactory()
        case .ecdsa: factory = EcdsaKeypairFactory()
        }
        let pair = try factory.createKeypairFromSeed(seed, chaincodeList: junctions.chaincodes)
        let signingKey: Data
        if let derivable = factory as? DerivableSeedFactoryProtocol {
            signingKey = try derivable.deriveChildSeedFromParent(seed, chaincodeList: junctions.chaincodes)
        } else {
            signingKey = pair.privateKey().rawData()
        }
        return Key(
            ecosystem: .substrate,
            type: type,
            path: path,
            publicKey: pair.publicKey().rawData(),
            secretKey: signingKey
        )
    }

    private static func readJSON(_ data: Data, password: String) throws -> Key {
        guard data.count <= 1_048_576 else { throw WalletError.invalidJSON("Backup is too large.") }
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)
        let encoding = definition.encoding
        guard encoding.content.count == 2, encoding.content[0] == "pkcs8",
              encoding.type.isEmpty || encoding.type == ["scrypt", "xsalsa20-poly1305"] else {
            throw WalletError.invalidJSON("Unsupported encoding.")
        }
        let isEthereum = encoding.content[1] == "ethereum"
        guard let type = isEthereum ? .ecdsa : WalletCore.CryptoType(rawValue: encoding.content[1]) else {
            throw WalletError.invalidJSON("Unsupported key type.")
        }
        // Request the unconverted PKCS#8 key bytes from the native extractor. On sr25519 its
        // legacy conversion calls a Rust ABI which requires an already validated expanded scalar.
        let raw = KeystoreDefinition(
            address: nil,
            encoded: definition.encoded,
            encoding:
            KeystoreEncoding(content: ["pkcs8", "ed25519"], type: encoding.type, version: encoding.version),
            meta: nil
        )
        let extracted: KeystoreData
        do { extracted = try KeystoreExtractor().extractFromDefinition(raw, password: password) }
        catch let error as NSError where error.domain.hasSuffix("NaclSecretBoxError") {
            throw WalletError.wrongJSONPassword
        }
        var secret = extracted.secretKeyData
        let publicKey = extracted.publicKeyData
        let mismatch = WalletError.invalidJSON("The backup keys and address do not match.")
        switch type {
        case .sr25519:
            // Schnorrkel's expanded scalar must be less than 8*l (little endian).
            let limit = try Data(hexStringSSF: "689faee7d21893c0b2e6bc17f5cef7a600000000000000000000000000000080")
            guard secret.count == 64, publicKey.count == 32, secret[0] & 7 == 0,
                  secret.prefix(32).reversed().lexicographicallyPrecedes(limit.reversed()) else { throw mismatch }
            secret = try SNPrivateKey(fromEd25519: secret).rawData()
            // The checked Native signer validates that the supplied public and secret keys match.
            _ = try SubstrateTransactionSigner(publicKeyData: publicKey, secretKeyData: secret, cryptoType: .sr25519)
                .sign(Data("Fearless backup key verification".utf8))
        case .ed25519:
            if secret.count == 64 {
                guard secret.suffix(32) == publicKey else { throw mismatch }
                secret = Data(secret.prefix(32))
            }
            guard secret.count == 32,
                  try EDKeyFactory().derive(fromSeed: secret).publicKey().rawData() == publicKey else { throw mismatch }
        case .ecdsa:
            guard secret.count == 32,
                  try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: secret)).publicKey()
                      .rawData() == publicKey
            else { throw mismatch }
        }
        let key = Key(
            ecosystem: isEthereum ? .evm : .substrate,
            type: type,
            path: nil,
            publicKey: publicKey,
            secretKey: secret
        )
        if let storedAddress = definition.address {
            let expected = try key.account().publicKey
            if isEthereum {
                guard try decodeEthereum(storedAddress) == expected else { throw mismatch }
            } else {
                let accountID = try expected.publicKeyToAccountId()
                if let hex = strictHex(storedAddress, bytes: 32) {
                    guard hex == accountID else { throw mismatch }
                } else {
                    guard try decodeSS58(storedAddress).id == accountID else { throw mismatch }
                }
            }
        }
        return key
    }

    private static func strictHex(_ input: String, bytes: Int) -> Data? {
        let value = input.hasPrefix("0x") ? input.dropFirst(2) : input[...]
        guard value.utf8.count == bytes * 2,
              value.utf8
                  .allSatisfy({ (48 ... 57).contains($0) || (65 ... 70).contains($0) || (97 ... 102).contains($0) })
        else { return nil }
        return try? Data(hexStringSSF: String(value))
    }

    private static func decodeSS58(_ string: String) throws -> (id: Data, prefix: UInt16) {
        let invalid = WalletError.invalidAddress("Enter a valid SS58 address.")
        guard (3 ... 50).contains(string.utf8.count) else { throw invalid }
        let data = NSData(base58String: string) as Data
        guard let first = data.first, first < 128, data.count == (first < 64 ? 35 : 36) else { throw invalid }
        let factory = SS58AddressFactory()
        let prefix = try factory.type(fromAddress: string).uint16Value
        guard prefix != 46, prefix != 47, (prefix < 64) == (first < 64) else { throw invalid }
        let id = try factory.accountId(fromAddress: string, type: prefix)
        guard try factory.address(fromAccountId: id, type: prefix) == string else { throw invalid }
        return (id, prefix)
    }

    private static func checksum(_ address: Data) throws -> String {
        try EthereumAddress(rawAddress: Array(address)).hex(eip55: true)
    }

    private static func decodeEthereum(_ address: String) throws -> Data {
        guard address.hasPrefix("0x"), let bytes = strictHex(address, bytes: 20),
              try address == address.lowercased() || address == checksum(bytes) else {
            throw WalletError.invalidAddress("Enter a lowercase or EIP-55 checksummed EVM address.")
        }
        return bytes
    }

    static func address(_ account: WalletAccount, prefix: UInt16?) throws -> String {
        if account.ecosystem == .evm {
            return try checksum(account.publicKey)
        }
        guard let prefix, prefix < 16384 else { throw WalletError.unsupportedChain }
        return try SS58AddressFactory().address(fromAccountId: account.publicKey.publicKeyToAccountId(), type: prefix)
    }

    static func validate(_ address: String, on chain: Catalog.Network) -> RecipientValidation {
        if address.isEmpty {
            return .empty
        }
        do {
            if chain.evmID != nil {
                return try .valid(normalized: checksum(decodeEthereum(address)))
            }
            let decoded = try decodeSS58(address)
            guard decoded.prefix == chain.prefix
            else { return .wrongNetwork(reason: "Use an address formatted for " + chain.name + ".") }
            return .valid(normalized: address)
        } catch { return .invalid(reason: "The address or its checksum is invalid.") }
    }
}
