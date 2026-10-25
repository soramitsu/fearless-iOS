import Foundation

/// Proves that captured Android SCALE source records describe the same keys and
/// recovery material as their FPWMSM01 slots. This is read-only evidence; iOS
/// still has no transactional cross-platform cohort installer.
enum IOSPortableAndroidSourceProof {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias Role = IOSPortableWalletSemanticMaterial.Role

    enum ProofError: Error, Equatable {
        case invalidSource
    }

    struct Counts: Equatable {
        let verifiedSources: Int
    }

    static func verify(_ encoded: Data) throws -> Counts {
        var snapshot: Codec.Snapshot
        do {
            snapshot = try Codec.decode(encoded)
        } catch {
            throw ProofError.invalidSource
        }
        defer { snapshot.clearSecrets() }

        var count = 0
        do {
            for wallet in snapshot.wallets {
                for source in wallet.slots where source.role == Role.auxiliarySource {
                    guard try source.number(FieldID.sourcePlatform) == 1 else { continue }
                    try verify(source, in: wallet)
                    count += 1
                }
            }
        } catch {
            throw ProofError.invalidSource
        }
        return Counts(verifiedSources: count)
    }

    // The source-role table must remain closed and visible in one place.
    // swiftlint:disable:next cyclomatic_complexity
    private static func verify(_ source: Codec.Slot, in wallet: Codec.Wallet) throws {
        guard try source.number(FieldID.sourceRecipe) == 0 else { throw ProofError.invalidSource }
        let sourceRole = try source.number(FieldID.sourceSlotRole)
        let primaryRole: UInt8
        switch sourceRole {
        case 10: primaryRole = Role.legacySubstrate
        case 11: primaryRole = Role.substrateRoot
        case 12: primaryRole = Role.evmRoot
        case 13: primaryRole = Role.tonRoot
        case 14: primaryRole = Role.chainAccount
        default: throw ProofError.invalidSource
        }
        let primary: Codec.Slot?
        if primaryRole == Role.chainAccount {
            let chainID = try Codec.strictText(source.value(FieldID.bindingChainID), allowEmpty: false)
            let accountID = try source.value(FieldID.bindingAccountID)
            primary = wallet.slots.first { $0.role == primaryRole && $0.key == chainID }
            guard let primary, try primary.value(FieldID.accountIDOrAddress) == accountID else {
                throw ProofError.invalidSource
            }
        } else {
            primary = wallet.slots.first { $0.role == primaryRole }
        }
        guard let primary else { throw ProofError.invalidSource }

        var cursor = try ScaleCursor(bytes: source.value(FieldID.sourceBytes))
        defer { cursor.clearSecrets() }
        switch sourceRole {
        case 10:
            try verifyLegacy(&cursor, primary: primary)
        case 13:
            try verifyTon(&cursor, primary: primary)
        default:
            try verifyKeypair(&cursor, primary: primary)
        }
        guard cursor.isAtEnd else { throw ProofError.invalidSource }
    }

    private static func verifyKeypair(_ cursor: inout ScaleCursor, primary: Codec.Slot) throws {
        let entropy = try cursor.optionalBytes(maximum: 8192)
        let seed = try cursor.optionalBytes(maximum: 8192)
        let privateKey = try cursor.bytes(maximum: 64)
        let publicKey = try cursor.bytes(maximum: 65)
        let nonce = try cursor.optionalBytes(maximum: 64)
        let path = try cursor.optionalText(maximum: 8192)
        let expectedPrivate = try primary.value(FieldID.privateKey)
        let expectedPublic = try primary.value(FieldID.publicKey)
        guard privateKey == expectedPrivate,
              publicKey == expectedPublic,
              matches(entropy, primary: primary, field: FieldID.entropy),
              matches(seed, primary: primary, field: FieldID.seed),
              matches(nonce, primary: primary, field: FieldID.nonce),
              matches(path, primary: primary, field: FieldID.derivationPath) else {
            throw ProofError.invalidSource
        }
    }

    private static func verifyTon(_ cursor: inout ScaleCursor, primary: Codec.Slot) throws {
        let seed = try cursor.bytes(maximum: 8192)
        let privateKey = try cursor.bytes(maximum: 64)
        let publicKey = try cursor.bytes(maximum: 65)
        let expectedSeed = try primary.value(FieldID.seed)
        let expectedPrivate = try primary.value(FieldID.privateKey)
        let expectedPublic = try primary.value(FieldID.publicKey)
        guard seed == expectedSeed,
              privateKey == expectedPrivate,
              publicKey == expectedPublic else {
            throw ProofError.invalidSource
        }
    }

    private static func verifyLegacy(_ cursor: inout ScaleCursor, primary: Codec.Slot) throws {
        let type = try cursor.text(maximum: 64)
        let recipes: [[UInt8]: UInt8] = [
            Array("CREATE".utf8): 1, Array("SEED".utf8): 2,
            Array("JSON".utf8): 3, Array("MNEMONIC".utf8): 4,
            Array("UNSPECIFIED".utf8): 5
        ]
        let privateKey = try cursor.bytes(maximum: 64)
        let publicKey = try cursor.bytes(maximum: 65)
        let nonce = try cursor.optionalBytes(maximum: 64)
        let seed = try cursor.optionalBytes(maximum: 8192)
        let mnemonic = try cursor.optionalText(maximum: 8192)
        let path = try cursor.optionalText(maximum: 8192)
        let expectedRecipe = try primary.number(FieldID.sourceRecipe)
        let expectedPrivate = try primary.value(FieldID.privateKey)
        let expectedPublic = try primary.value(FieldID.publicKey)
        guard let recipe = recipes[type], recipe == expectedRecipe,
              privateKey == expectedPrivate,
              publicKey == expectedPublic,
              matches(nonce, primary: primary, field: FieldID.nonce),
              matches(seed, primary: primary, field: FieldID.seed),
              matches(mnemonic, primary: primary, field: FieldID.mnemonic),
              matches(path, primary: primary, field: FieldID.derivationPath) else {
            throw ProofError.invalidSource
        }
    }

    private static func matches(_ value: [UInt8]?, primary: Codec.Slot, field: UInt8) -> Bool {
        value == primary.fields.first(where: { $0.id == field })?.value
    }

    /// Lengths are checked against both the Android schema bound and remaining
    /// input before slicing. Android's maximum field is below SCALE's four-byte
    /// compact threshold, so longer compact modes cannot be canonical here.
    private struct ScaleCursor {
        private var source: [UInt8]
        private var offset = 0

        init(bytes: [UInt8]) {
            source = bytes
        }

        var isAtEnd: Bool {
            offset == source.count
        }

        mutating func clearSecrets() {
            for index in source.indices {
                source[index] = 0
            }
        }

        mutating func bytes(maximum: Int) throws -> [UInt8] {
            let count = try compactLength(maximum: maximum)
            guard count <= source.count - offset else { throw ProofError.invalidSource }
            defer { offset += count }
            return Array(source[offset ..< offset + count])
        }

        mutating func text(maximum: Int) throws -> [UInt8] {
            let value = try bytes(maximum: maximum)
            guard let decoded = String(bytes: value, encoding: .utf8),
                  Array(decoded.utf8) == value else { throw ProofError.invalidSource }
            return value
        }

        mutating func optionalBytes(maximum: Int) throws -> [UInt8]? {
            switch try byte() {
            case 0: return nil
            case 1: return try bytes(maximum: maximum)
            default: throw ProofError.invalidSource
            }
        }

        mutating func optionalText(maximum: Int) throws -> [UInt8]? {
            switch try byte() {
            case 0: return nil
            case 1: return try text(maximum: maximum)
            default: throw ProofError.invalidSource
            }
        }

        private mutating func byte() throws -> UInt8 {
            guard offset < source.count else { throw ProofError.invalidSource }
            defer { offset += 1 }
            return source[offset]
        }

        private mutating func compactLength(maximum: Int) throws -> Int {
            let first = try Int(byte())
            let value: Int
            switch first & 3 {
            case 0:
                value = first >> 2
            case 1:
                value = try (first | (Int(byte()) << 8)) >> 2
                guard value >= 64 else { throw ProofError.invalidSource }
            default:
                throw ProofError.invalidSource
            }
            guard value <= maximum else { throw ProofError.invalidSource }
            return value
        }
    }
}
