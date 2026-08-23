import BigInt
import CommonCrypto
import Foundation
import IrohaCrypto
import SoraKeystore
import SSFModels
import secp256k1

/// Versioned bridge for wallets that were imported from a 32-byte raw wallet
/// seed instead of BIP39 words. The raw seed is used directly as BIP39 entropy;
/// no hash, random value, or irreversible synthetic secret is introduced.
/// Restoring the same raw wallet seed therefore recreates the same app-owned
/// accounts, while mnemonic wallets continue to use their original entropy.
enum UniversalWalletSeedBridge {
    static let contract = "raw-wallet-seed-as-bip39-entropy-v1"
    static let walletSeedLength = 32

    enum BridgeError: Error, Equatable {
        case invalidWalletSeedLength
    }

    static func mnemonic(fromWalletSeed walletSeed: Data) throws -> String {
        guard walletSeed.count == walletSeedLength else {
            throw BridgeError.invalidWalletSeedLength
        }

        return try IRMnemonicCreator()
            .mnemonic(fromEntropy: walletSeed)
            .toString()
    }
}

protocol UniversalWalletStoredSeedAdopting {
    func adoptStoredSecret(for wallet: MetaAccountModel) throws -> MetaAccountModel
}

/// Establishes an explicit, versioned recovery contract for a legacy raw-seed
/// wallet. An unmarked stored seed is never interpreted automatically: the UI
/// calls this only after the owner confirms the adoption. Authentic BIP39 root
/// entropy remains authoritative and never receives a raw-seed marker.
final class UniversalWalletStoredSeedAdopter: UniversalWalletStoredSeedAdopting {
    enum AdoptionError: LocalizedError, ErrorContentConvertible, Equatable {
        case storedWalletSeedUnavailable
        case unsupportedSecretSource
        case conflictingUniversalWalletAccount

        var errorDescription: String? {
            switch self {
            case .storedWalletSeedUnavailable:
                return "This wallet has no compatible stored recovery secret. Import its original mnemonic or raw seed backup instead."
            case .unsupportedSecretSource:
                return "This wallet uses a different recovery contract and was not changed."
            case .conflictingUniversalWalletAccount:
                return "An existing Bitcoin or Taira account needs manual recovery and was not changed."
            }
        }

        func toErrorContent(for locale: Locale?) -> ErrorContent {
            ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: errorDescription ?? "Bitcoin and Taira accounts were not created."
            )
        }
    }

    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    func adoptStoredSecret(for wallet: MetaAccountModel) throws -> MetaAccountModel {
        try validateNoConflictingAccounts(in: wallet)

        if let rootEntropy = try fetchIfPresent(
            tag: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        ) {
            let mnemonic: String
            do {
                mnemonic = try IRMnemonicCreator()
                    .mnemonic(fromEntropy: rootEntropy)
                    .toString()
            } catch {
                throw AdoptionError.storedWalletSeedUnavailable
            }
            return try updatedWallet(from: wallet, mnemonic: mnemonic)
        }

        let sourceTag = KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        if let source = try fetchIfPresent(tag: sourceTag),
           String(data: source, encoding: .utf8) != UniversalWalletSeedBridge.contract {
            throw AdoptionError.unsupportedSecretSource
        }

        guard let walletSeed = try fetchIfPresent(
            tag: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        ) else {
            throw AdoptionError.storedWalletSeedUnavailable
        }

        let mnemonic: String
        do {
            mnemonic = try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        } catch UniversalWalletSeedBridge.BridgeError.invalidWalletSeedLength {
            throw AdoptionError.storedWalletSeedUnavailable
        }

        let updatedWallet = try updatedWallet(from: wallet, mnemonic: mnemonic)

        // Persist the contract before the wallet row. If the database save
        // subsequently fails, retrying derives the same accounts and is safe.
        // Derivation and conflict validation have already succeeded, so a
        // failed adoption never leaves a marker for an unusable identity.
        try keystore.saveKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: sourceTag
        )

        return updatedWallet
    }

    private func validateNoConflictingAccounts(in wallet: MetaAccountModel) throws {
        let bitcoinAccounts = wallet.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }
        let tairaAccounts = wallet.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
        }

        guard bitcoinAccounts.allSatisfy({
            UniversalWalletChainAccountSupport.isValidBitcoinAccount($0)
        }), tairaAccounts.allSatisfy(
            UniversalWalletChainAccountSupport.isValidTairaAccount
        ) else {
            throw AdoptionError.conflictingUniversalWalletAccount
        }
    }

    private func updatedWallet(
        from wallet: MetaAccountModel,
        mnemonic: String
    ) throws -> MetaAccountModel {
        let bitcoinCandidate = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            network: .mainnet
        )
        let tairaCandidate = try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic)

        try validateExistingAccounts(
            in: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            candidatePublicKey: bitcoinCandidate.publicKey,
            isStructurallyValid: {
                UniversalWalletChainAccountSupport.isValidBitcoinAccount($0)
            },
            derivePublicKey: {
                try BitcoinKeyDerivation.deriveAccount(
                    mnemonic: $0,
                    network: .mainnet
                ).publicKey
            }
        )
        try validateExistingAccounts(
            in: wallet,
            chainId: UniversalWalletRegistry.taira.chainId,
            candidatePublicKey: tairaCandidate.publicKey,
            isStructurallyValid: UniversalWalletChainAccountSupport.isValidTairaAccount,
            derivePublicKey: { try IrohaKeyDerivation.deriveAccount(mnemonic: $0).publicKey }
        )

        return try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: mnemonic
        )
    }

    private func validateExistingAccounts(
        in wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        candidatePublicKey: Data,
        isStructurallyValid: (ChainAccountModel) -> Bool,
        derivePublicKey: (String) throws -> Data
    ) throws {
        let accounts = wallet.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
        }
        guard accounts.count <= 1 else {
            throw AdoptionError.conflictingUniversalWalletAccount
        }
        guard let account = accounts.first else {
            return
        }
        guard isStructurallyValid(account) else {
            throw AdoptionError.conflictingUniversalWalletAccount
        }
        guard account.publicKey != candidatePublicKey else {
            return
        }

        let accountEntropyTag = KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: account.accountId
        )
        guard let accountEntropy = try fetchIfPresent(tag: accountEntropyTag) else {
            throw AdoptionError.conflictingUniversalWalletAccount
        }

        do {
            let accountMnemonic = try IRMnemonicCreator()
                .mnemonic(fromEntropy: accountEntropy)
                .toString()
            guard try derivePublicKey(accountMnemonic) == account.publicKey else {
                throw AdoptionError.conflictingUniversalWalletAccount
            }
        } catch let error as AdoptionError {
            throw error
        } catch {
            throw AdoptionError.conflictingUniversalWalletAccount
        }
    }

    private func fetchIfPresent(tag: String) throws -> Data? {
        do {
            return try keystore.fetchKey(for: tag)
        } catch KeystoreError.noKeyFound {
            return nil
        }
    }
}

enum BitcoinKeyDerivation {
    enum Network: Equatable {
        case mainnet
        case testnet

        var hrp: String {
            switch self {
            case .mainnet:
                return "bc"
            case .testnet:
                return "tb"
            }
        }

        var accountPath: String {
            switch self {
            case .mainnet:
                return UniversalWalletDerivationPaths.bitcoinMainnetAccount
            case .testnet:
                return UniversalWalletDerivationPaths.bitcoinTestnetAccount
            }
        }

        var firstReceivePath: String {
            switch self {
            case .mainnet:
                return UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive
            case .testnet:
                return UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive
            }
        }
    }

    enum DerivationError: Error, Equatable {
        case emptyMnemonic
        case emptySeed
        case invalidDerivationPath
        case invalidDerivationIndex
        case invalidPrivateKeyLength
        case invalidPrivateKeyRange
        case invalidPublicKeyLength
        case childPrivateKeyTweakOutOfRange
        case childPrivateKeyIsZero
        case keyDerivationFailed
        case secp256k1ContextUnavailable
        case publicKeyCannotBeCreated
        case publicKeyCannotBeSerialized
        case integerDoesNotFit
    }

    struct Account: Equatable {
        let network: Network
        let accountPath: String
        let firstReceivePath: String
        let accountXpub: String
        let privateKey: Data
        let chainCode: Data
        let publicKey: Data
        let firstReceiveAddress: String
    }

    struct DerivedKey: Equatable {
        let network: Network
        let derivationPath: String
        let privateKey: Data
        let chainCode: Data
        let publicKey: Data
        let address: String
    }

    struct ExtendedPrivateKey: Equatable {
        let privateKey: Data
        let chainCode: Data
        let depth: Int
        let parentFingerprint: Data
        let childNumber: UInt32
    }

    private struct PathComponent {
        let index: UInt32
        let hardened: Bool

        var serializedIndex: UInt32 {
            index + (hardened ? BitcoinKeyDerivation.hardenedOffset : 0)
        }
    }

    private static let bitcoinSeedKey = Data("Bitcoin seed".utf8)
    private static let hardenedOffset: UInt32 = 0x8000_0000
    private static let maxChildIndex: UInt32 = 0x7FFF_FFFF
    private static let privateKeyLength = 32
    private static let publicKeyLength = 33
    private static let chainCodeLength = 32
    private static let bip39Rounds = 2048
    private static let bip39SeedLength = 64
    private static let xpubPayloadLength = 78
    private static let xpubVersion: UInt32 = 0x0488_B21E
    private static let curveOrder = BigUInt(
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141",
        radix: 16
    )!
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let bech32Alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private static let bech32Generators: [Int] = [
        0x3B6A_57B2,
        0x2650_8E6D,
        0x1EA1_19FA,
        0x3D42_33DD,
        0x2A14_62B3
    ]

    static func deriveAccount(
        mnemonic: String,
        passphrase: String = "",
        network: Network = .mainnet
    ) throws -> Account {
        let normalizedMnemonic = try normalizeMnemonic(mnemonic)
        let seed = try bip39Seed(mnemonic: normalizedMnemonic, passphrase: passphrase)
        let accountNode = try derivePrivateKey(seed: seed, derivationPath: network.accountPath)
        let receiveNode = try derivePrivateKey(seed: seed, derivationPath: network.firstReceivePath)
        let receivePublicKey = try publicKey(fromPrivateKey: receiveNode.privateKey)

        return Account(
            network: network,
            accountPath: network.accountPath,
            firstReceivePath: network.firstReceivePath,
            accountXpub: try serializeXpub(accountNode),
            privateKey: receiveNode.privateKey,
            chainCode: receiveNode.chainCode,
            publicKey: receivePublicKey,
            firstReceiveAddress: try address(fromPublicKey: receivePublicKey, network: network)
        )
    }

    static func deriveKey(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String,
        network: Network = .mainnet
    ) throws -> DerivedKey {
        let normalizedMnemonic = try normalizeMnemonic(mnemonic)
        let seed = try bip39Seed(mnemonic: normalizedMnemonic, passphrase: passphrase)
        let node = try derivePrivateKey(seed: seed, derivationPath: derivationPath)
        let derivedPublicKey = try publicKey(fromPrivateKey: node.privateKey)

        return DerivedKey(
            network: network,
            derivationPath: derivationPath,
            privateKey: node.privateKey,
            chainCode: node.chainCode,
            publicKey: derivedPublicKey,
            address: try address(fromPublicKey: derivedPublicKey, network: network)
        )
    }

    static func derivePrivateKey(seed: Data, derivationPath: String) throws -> ExtendedPrivateKey {
        guard !seed.isEmpty else {
            throw DerivationError.emptySeed
        }

        let digest = hmacSha512(key: bitcoinSeedKey, data: seed)
        var node = ExtendedPrivateKey(
            privateKey: try validatePrivateKey(Data(digest.prefix(privateKeyLength))),
            chainCode: Data(digest.suffix(chainCodeLength)),
            depth: 0,
            parentFingerprint: Data(repeating: 0, count: 4),
            childNumber: 0
        )

        for component in try parseDerivationPath(derivationPath) {
            node = try deriveChild(parent: node, component: component)
        }

        return node
    }

    static func publicKey(fromPrivateKey privateKey: Data) throws -> Data {
        guard privateKey.count == privateKeyLength else {
            throw DerivationError.invalidPrivateKeyLength
        }

        _ = try validatePrivateKey(privateKey)

        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN)) else {
            throw DerivationError.secp256k1ContextUnavailable
        }

        defer {
            secp256k1_context_destroy(context)
        }

        var publicKey = secp256k1_pubkey()
        let createResult = privateKey.withUnsafeBytes { keyBytes in
            guard let keyPointer = keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }

            return Int(secp256k1_ec_pubkey_create(context, &publicKey, keyPointer))
        }

        guard createResult != 0 else {
            throw DerivationError.publicKeyCannotBeCreated
        }

        var outputLength = publicKeyLength
        var output = Data(repeating: 0, count: outputLength)
        let serializeResult = output.withUnsafeMutableBytes { outputBytes in
            withUnsafeMutablePointer(to: &outputLength) { outputLengthPointer in
                withUnsafePointer(to: &publicKey) { publicKeyPointer in
                    guard let outputPointer = outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return 0
                    }

                    return Int(secp256k1_ec_pubkey_serialize(
                        context,
                        outputPointer,
                        outputLengthPointer,
                        publicKeyPointer,
                        UInt32(SECP256K1_EC_COMPRESSED)
                    ))
                }
            }
        }

        guard serializeResult != 0 else {
            throw DerivationError.publicKeyCannotBeSerialized
        }

        return output
    }

    static func address(fromPublicKey publicKey: Data, network: Network = .mainnet) throws -> String {
        guard publicKey.count == publicKeyLength else {
            throw DerivationError.invalidPublicKeyLength
        }

        let witnessProgram = hash160(publicKey)
        return try bech32Encode(
            hrp: network.hrp,
            values: [0] + convertBits(Array(witnessProgram), fromBits: 8, toBits: 5, pad: true)
        )
    }

    static func getReceivePath(network: Network = .mainnet, index: UInt32 = 0, change: UInt32 = 0) throws -> String {
        guard index <= maxChildIndex else {
            throw DerivationError.invalidDerivationIndex
        }

        guard change == 0 || change == 1 else {
            throw DerivationError.invalidDerivationIndex
        }

        let coinType: UInt32 = network == .mainnet ? 0 : 1
        return "m/84'/\(coinType)'/0'/\(change)/\(index)"
    }

    private static func deriveChild(parent: ExtendedPrivateKey, component: PathComponent) throws -> ExtendedPrivateKey {
        let serializedIndex = component.serializedIndex
        var data = Data()

        if component.hardened {
            data.append(0)
            data.append(parent.privateKey)
        } else {
            data.append(try publicKey(fromPrivateKey: parent.privateKey))
        }

        appendUInt32(serializedIndex, to: &data)

        let digest = hmacSha512(key: parent.chainCode, data: data)
        let tweak = BigUInt(Data(digest.prefix(privateKeyLength)))

        guard tweak < curveOrder else {
            throw DerivationError.childPrivateKeyTweakOutOfRange
        }

        let parentKey = BigUInt(parent.privateKey)
        let childKey = (tweak + parentKey) % curveOrder

        guard childKey > BigUInt.zero else {
            throw DerivationError.childPrivateKeyIsZero
        }

        let parentFingerprint = fingerprint(try publicKey(fromPrivateKey: parent.privateKey))

        return ExtendedPrivateKey(
            privateKey: try childKey.fixedLengthData(privateKeyLength),
            chainCode: Data(digest.suffix(chainCodeLength)),
            depth: parent.depth + 1,
            parentFingerprint: parentFingerprint,
            childNumber: serializedIndex
        )
    }

    private static func serializeXpub(_ node: ExtendedPrivateKey) throws -> String {
        let nodePublicKey = try publicKey(fromPrivateKey: node.privateKey)
        var payload = Data(capacity: xpubPayloadLength)

        appendUInt32(xpubVersion, to: &payload)
        payload.append(UInt8(node.depth))
        payload.append(node.parentFingerprint)
        appendUInt32(node.childNumber, to: &payload)
        payload.append(node.chainCode)
        payload.append(nodePublicKey)

        return base58CheckEncode(payload)
    }

    private static func parseDerivationPath(_ derivationPath: String) throws -> [PathComponent] {
        guard !derivationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DerivationError.invalidDerivationPath
        }

        guard derivationPath == "m" || derivationPath.hasPrefix("m/") else {
            throw DerivationError.invalidDerivationPath
        }

        guard derivationPath != "m" else {
            return []
        }

        return try derivationPath
            .dropFirst(2)
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { component in
                let hardened = component.hasSuffix("'")
                let indexText = hardened ? component.dropLast() : component

                guard !indexText.isEmpty, let index = UInt32(indexText), index <= maxChildIndex else {
                    throw DerivationError.invalidDerivationIndex
                }

                return PathComponent(index: index, hardened: hardened)
            }
    }

    private static func normalizeMnemonic(_ mnemonic: String) throws -> String {
        let normalized = mnemonic.decomposedStringWithCompatibilityMapping
        let words = normalized
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !words.isEmpty else {
            throw DerivationError.emptyMnemonic
        }

        return words.joined(separator: " ")
            .decomposedStringWithCompatibilityMapping
    }

    private static func bip39Seed(mnemonic: String, passphrase: String) throws -> Data {
        let password = Array(mnemonic.utf8)
        let normalizedPassphrase = passphrase.decomposedStringWithCompatibilityMapping
        let salt = Array("mnemonic\(normalizedPassphrase)".utf8)
        var output = [UInt8](repeating: 0, count: bip39SeedLength)

        let status = password.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBufferPointer { saltBuffer in
                passwordBuffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: password.count) { passwordPointer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer,
                        password.count,
                        saltBuffer.baseAddress!,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(bip39Rounds),
                        &output,
                        output.count
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw DerivationError.keyDerivationFailed
        }

        return Data(output)
    }

    private static func hmacSha512(key: Data, data: Data) -> Data {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))

        key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA512),
                    keyBytes.baseAddress!,
                    key.count,
                    dataBytes.baseAddress!,
                    data.count,
                    &output
                )
            }
        }

        return Data(output)
    }

    private static func sha256(_ data: Data) -> Data {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes { dataBytes in
            _ = CC_SHA256(dataBytes.baseAddress, CC_LONG(data.count), &output)
        }

        return Data(output)
    }

    private static func hash160(_ data: Data) -> Data {
        ripemd160(sha256(data))
    }

    private static func fingerprint(_ publicKey: Data) -> Data {
        Data(hash160(publicKey).prefix(4))
    }

    private static func validatePrivateKey(_ privateKey: Data) throws -> Data {
        let privateKeyValue = BigUInt(privateKey)

        guard privateKeyValue > BigUInt.zero, privateKeyValue < curveOrder else {
            throw DerivationError.invalidPrivateKeyRange
        }

        return privateKey
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    private static func base58CheckEncode(_ payload: Data) -> String {
        let checksum = Data(sha256(sha256(payload)).prefix(4))
        return base58Encode(Array(payload + checksum))
    }

    private static func base58Encode(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else {
            return ""
        }

        var digits: [Int] = []

        for byte in bytes {
            var carry = Int(byte)

            for index in digits.indices {
                let value = digits[index] * 256 + carry
                digits[index] = value % base58Alphabet.count
                carry = value / base58Alphabet.count
            }

            while carry > 0 {
                digits.append(carry % base58Alphabet.count)
                carry /= base58Alphabet.count
            }
        }

        var result = String(repeating: String(base58Alphabet[0]), count: bytes.prefix { $0 == 0 }.count)
        for digit in digits.reversed() {
            result.append(base58Alphabet[digit])
        }

        return result
    }

    private static func bech32Encode(hrp: String, values: [Int]) throws -> String {
        guard !hrp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DerivationError.invalidDerivationPath
        }

        let encodedValues = values + bech32CreateChecksum(hrp: hrp, values: values)
        return hrp + "1" + encodedValues.map { String(bech32Alphabet[$0]) }.joined()
    }

    private static func bech32CreateChecksum(hrp: String, values: [Int]) -> [Int] {
        let polymodValues = expandHrp(hrp) + values + Array(repeating: 0, count: 6)
        let polymod = bech32Polymod(polymodValues) ^ 1

        return (0 ..< 6).map { index in
            (polymod >> (5 * (5 - index))) & 31
        }
    }

    private static func bech32Polymod(_ values: [Int]) -> Int {
        var checksum = 1

        for value in values {
            let top = checksum >> 25
            checksum = ((checksum & 0x1FFFFFF) << 5) ^ value

            for (index, generator) in bech32Generators.enumerated() where ((top >> index) & 1) == 1 {
                checksum ^= generator
            }
        }

        return checksum
    }

    private static func expandHrp(_ hrp: String) -> [Int] {
        hrp.map { Int($0.asciiValue ?? 0) >> 5 } + [0] + hrp.map { Int($0.asciiValue ?? 0) & 31 }
    }

    private static func convertBits(_ values: [UInt8], fromBits: Int, toBits: Int, pad: Bool) throws -> [Int] {
        var accumulator = 0
        var bits = 0
        let maxValue = (1 << toBits) - 1
        let maxAccumulator = (1 << (fromBits + toBits - 1)) - 1
        var result: [Int] = []

        for rawValue in values {
            let value = Int(rawValue)

            guard value >> fromBits == 0 else {
                throw DerivationError.invalidPublicKeyLength
            }

            accumulator = ((accumulator << fromBits) | value) & maxAccumulator
            bits += fromBits

            while bits >= toBits {
                bits -= toBits
                result.append((accumulator >> bits) & maxValue)
            }
        }

        if pad {
            if bits > 0 {
                result.append((accumulator << (toBits - bits)) & maxValue)
            }
        } else {
            guard bits < fromBits, ((accumulator << (toBits - bits)) & maxValue) == 0 else {
                throw DerivationError.invalidPublicKeyLength
            }
        }

        return result
    }

    private static func ripemd160(_ data: Data) -> Data {
        var message = Array(data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)

        while message.count % 64 != 56 {
            message.append(0)
        }

        var littleEndianBitLength = bitLength.littleEndian
        withUnsafeBytes(of: &littleEndianBitLength) { message.append(contentsOf: $0) }

        var h0: UInt32 = 0x6745_2301
        var h1: UInt32 = 0xEFCD_AB89
        var h2: UInt32 = 0x98BA_DCFE
        var h3: UInt32 = 0x1032_5476
        var h4: UInt32 = 0xC3D2_E1F0

        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 16)
            for index in 0 ..< 16 {
                let offset = chunkStart + index * 4
                words[index] = UInt32(message[offset])
                    | (UInt32(message[offset + 1]) << 8)
                    | (UInt32(message[offset + 2]) << 16)
                    | (UInt32(message[offset + 3]) << 24)
            }

            var a1 = h0
            var b1 = h1
            var c1 = h2
            var d1 = h3
            var e1 = h4
            var a2 = h0
            var b2 = h1
            var c2 = h2
            var d2 = h3
            var e2 = h4

            for index in 0 ..< 80 {
                let left = rotateLeft(
                    a1
                        &+ ripemd160F(index, b1, c1, d1)
                        &+ words[ripemd160R1[index]]
                        &+ ripemd160K1(index),
                    by: ripemd160S1[index]
                ) &+ e1
                a1 = e1
                e1 = d1
                d1 = rotateLeft(c1, by: 10)
                c1 = b1
                b1 = left

                let right = rotateLeft(
                    a2
                        &+ ripemd160F(79 - index, b2, c2, d2)
                        &+ words[ripemd160R2[index]]
                        &+ ripemd160K2(index),
                    by: ripemd160S2[index]
                ) &+ e2
                a2 = e2
                e2 = d2
                d2 = rotateLeft(c2, by: 10)
                c2 = b2
                b2 = right
            }

            let temporary = h1 &+ c1 &+ d2
            h1 = h2 &+ d1 &+ e2
            h2 = h3 &+ e1 &+ a2
            h3 = h4 &+ a1 &+ b2
            h4 = h0 &+ b1 &+ c2
            h0 = temporary
        }

        var output = Data(capacity: 20)
        [h0, h1, h2, h3, h4].forEach { value in
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { output.append(contentsOf: $0) }
        }

        return output
    }

    private static func rotateLeft(_ value: UInt32, by shift: Int) -> UInt32 {
        (value << shift) | (value >> (32 - shift))
    }

    private static func ripemd160F(_ index: Int, _ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        switch index {
        case 0 ... 15:
            return x ^ y ^ z
        case 16 ... 31:
            return (x & y) | (~x & z)
        case 32 ... 47:
            return (x | ~y) ^ z
        case 48 ... 63:
            return (x & z) | (y & ~z)
        default:
            return x ^ (y | ~z)
        }
    }

    private static func ripemd160K1(_ index: Int) -> UInt32 {
        switch index {
        case 0 ... 15:
            return 0x0000_0000
        case 16 ... 31:
            return 0x5A82_7999
        case 32 ... 47:
            return 0x6ED9_EBA1
        case 48 ... 63:
            return 0x8F1B_BCDC
        default:
            return 0xA953_FD4E
        }
    }

    private static func ripemd160K2(_ index: Int) -> UInt32 {
        switch index {
        case 0 ... 15:
            return 0x50A2_8BE6
        case 16 ... 31:
            return 0x5C4D_D124
        case 32 ... 47:
            return 0x6D70_3EF3
        case 48 ... 63:
            return 0x7A6D_76E9
        default:
            return 0x0000_0000
        }
    }

    private static let ripemd160R1 = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
        3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
        1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
        4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13
    ]

    private static let ripemd160R2 = [
        5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
        6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
        15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
        8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
        12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11
    ]

    private static let ripemd160S1 = [
        11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
        7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
        11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
        11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
        9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6
    ]

    private static let ripemd160S2 = [
        8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
        9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
        9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
        15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
        8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11
    ]
}

private extension BigUInt {
    func fixedLengthData(_ length: Int) throws -> Data {
        let serialized = serialize()

        guard serialized.count <= length else {
            throw BitcoinKeyDerivation.DerivationError.integerDoesNotFit
        }

        return Data(repeating: 0, count: length - serialized.count) + serialized
    }
}
