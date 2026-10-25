import Foundation

/// Plaintext FPWMSM01 inventory for an encrypted FPWMLE01 portable envelope.
/// Structural validation does not authorize capture, signing, export, or installation.
enum IOSPortableWalletSemanticMaterial {
    enum CodecError: Error, Equatable {
        case invalidMaterial
    }

    enum Role {
        static let substrateRoot: UInt8 = 1
        static let evmRoot: UInt8 = 2
        static let tonRoot: UInt8 = 3
        static let legacySubstrate: UInt8 = 4
        static let chainAccount: UInt8 = 5
        static let favoriteChain: UInt8 = 6
        static let auxiliarySource: UInt8 = 7
        static let watchIdentity: UInt8 = 8
    }

    enum FieldID {
        static let publicKey: UInt8 = 1
        static let privateKey: UInt8 = 2
        static let nonce: UInt8 = 3
        static let entropy: UInt8 = 4
        static let seed: UInt8 = 5
        static let derivationPath: UInt8 = 6
        static let accountIDOrAddress: UInt8 = 7
        static let cryptoType: UInt8 = 8
        static let chainName: UInt8 = 9
        static let initializedOrFavorite: UInt8 = 10
        static let sourceRecipe: UInt8 = 11
        static let mnemonic: UInt8 = 12
        static let tonContractVersion: UInt8 = 13
        static let tonAddressEncoding: UInt8 = 14
        static let sourcePlatform: UInt8 = 15
        static let sourceSlotRole: UInt8 = 16
        static let bindingKind: UInt8 = 17
        static let bindingChainID: UInt8 = 18
        static let sourceFormat: UInt8 = 19
        static let sourceBytes: UInt8 = 20
        static let bindingAccountID: UInt8 = 21
        static let watchEcosystem: UInt8 = 22
        static let watchChainID: UInt8 = 23
    }

    enum MetadataID {
        static let assetKeysOrder: UInt8 = 1
        static let unusedChainIDs: UInt8 = 2
        static let selectedCurrency: UInt8 = 3
        static let networkManagementFilter: UInt8 = 4
        static let assetVisibility: UInt8 = 5
        static let favoriteChainIDs: UInt8 = 6
        static let assetFilterOptions: UInt8 = 7
        static let zeroBalanceAssetsHidden: UInt8 = 8
        static let canExportEthereumMnemonic: UInt8 = 9
        static let androidSelectedChainID: UInt8 = 10
        static let androidChainSelectFilter: UInt8 = 11
        static let androidAssetRowPresentation: UInt8 = 12
    }

    struct Snapshot: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let selectedIndex: Int
        var wallets: [Wallet]

        /// Best-effort overwrite of this value's arrays. Swift copy-on-write cannot clear prior copies.
        mutating func clearSecrets() {
            for index in wallets.indices {
                wallets[index].clearSecrets()
            }
        }

        var description: String { "IOSPortableWalletSemanticMaterial.Snapshot(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    struct Wallet: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        var portableID: [UInt8]
        let sourcePosition: UInt32
        let initialized: Bool
        let name: String
        var metadata: [Metadata]
        var slots: [Slot]

        mutating func clearSecrets() {
            for index in portableID.indices {
                portableID[index] = 0
            }
            for index in metadata.indices {
                metadata[index].clearSecrets()
            }
            for index in slots.indices {
                slots[index].clearSecrets()
            }
        }

        var description: String { "IOSPortableWalletSemanticMaterial.Wallet(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    struct Metadata: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let id: UInt8
        var value: [UInt8]

        mutating func clearSecrets() {
            for index in value.indices {
                value[index] = 0
            }
        }

        var description: String { "IOSPortableWalletSemanticMaterial.Metadata(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    struct Slot: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let role: UInt8
        let key: String
        var fields: [Field]

        func value(_ id: UInt8) throws -> [UInt8] {
            guard let value = fields.first(where: { $0.id == id })?.value else {
                throw CodecError.invalidMaterial
            }
            return value
        }

        func number(_ id: UInt8) throws -> UInt8 {
            let bytes = try value(id)
            guard bytes.count == 1 else { throw CodecError.invalidMaterial }
            return bytes[0]
        }

        mutating func clearSecrets() {
            for index in fields.indices {
                fields[index].clearSecrets()
            }
        }

        var description: String { "IOSPortableWalletSemanticMaterial.Slot(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    struct Field: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let id: UInt8
        var value: [UInt8]

        mutating func clearSecrets() {
            for index in value.indices {
                value[index] = 0
            }
        }

        var description: String { "IOSPortableWalletSemanticMaterial.Field(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    static let magic = Array("FPWMSM01".utf8)
    static let version: UInt8 = 1
    static let maxBytes = 256 * 1024 - 44 - 16
    static let maxWallets = 128
    static let maxSlots = 1412
    static let maxChains = 128
    static let maxAuxiliary = 1024
    static let maxWatch = 128
    static let maxText = 2048
    static let maxSecret = 32 * 1024
    static let maxPublic = 128

    static func encode(_ snapshot: Snapshot) throws -> Data {
        try validate(snapshot)
        var writer = Writer()
        defer { writer.erase() }
        try writer.write(magic)
        try writer.write(version)
        try writer.writeUInt16(snapshot.wallets.count)
        try writer.writeUInt16(snapshot.selectedIndex)
        for wallet in snapshot.wallets {
            try writer.write(wallet.portableID)
            try writer.writeUInt32(wallet.sourcePosition)
            try writer.write(wallet.initialized ? 1 : 0)
            try writer.writeText(wallet.name)
            try writer.write(UInt8(wallet.metadata.count))
            for item in wallet.metadata {
                try writer.write(item.id)
                try writer.writeValue(item.value)
            }
            try writer.writeUInt16(wallet.slots.count)
            for slot in wallet.slots {
                try writer.write(slot.role)
                try writer.writeText(slot.key)
                try writer.write(UInt8(slot.fields.count))
                for field in slot.fields {
                    try writer.write(field.id)
                    try writer.writeValue(field.value)
                }
            }
        }
        return Data(writer.bytes)
    }

    static func decode(_ encoded: Data) throws -> Snapshot {
        guard (30 ... maxBytes).contains(encoded.count) else { throw CodecError.invalidMaterial }
        var cursor = Cursor(bytes: Array(encoded))
        defer { cursor.erase() }
        guard try cursor.read(magic.count) == magic, try cursor.readByte() == version else {
            throw CodecError.invalidMaterial
        }
        let walletCount = try cursor.readUInt16()
        guard (1 ... maxWallets).contains(walletCount) else { throw CodecError.invalidMaterial }
        let selectedIndex = try cursor.readUInt16()
        guard selectedIndex < walletCount else { throw CodecError.invalidMaterial }
        var snapshot = Snapshot(selectedIndex: selectedIndex, wallets: [])
        do {
            snapshot.wallets.reserveCapacity(walletCount)
            for _ in 0 ..< walletCount {
                snapshot.wallets.append(try decodeWallet(from: &cursor))
            }
            guard cursor.isAtEnd else { throw CodecError.invalidMaterial }
            try validate(snapshot)
            return snapshot
        } catch {
            snapshot.clearSecrets()
            throw error
        }
    }
}

extension IOSPortableWalletSemanticMaterial {
    static func decodeWallet(from cursor: inout Cursor) throws -> Wallet {
        var portableID = [UInt8]()
        var metadata = [Metadata]()
        var slots = [Slot]()
        do {
            portableID = try cursor.read(16)
            let sourcePosition = try cursor.readUInt32()
            let initialized = try cursor.readBoolean()
            let name = try cursor.readText(allowEmpty: true)
            let metadataCount = Int(try cursor.readByte())
            guard metadataCount <= Int(MetadataID.androidAssetRowPresentation) else {
                throw CodecError.invalidMaterial
            }
            metadata.reserveCapacity(metadataCount)
            for _ in 0 ..< metadataCount {
                metadata.append(Metadata(id: try cursor.readByte(), value: try cursor.readValue()))
            }
            let slotCount = try cursor.readUInt16()
            guard (1 ... maxSlots).contains(slotCount) else { throw CodecError.invalidMaterial }
            slots.reserveCapacity(slotCount)
            for _ in 0 ..< slotCount {
                slots.append(try decodeSlot(from: &cursor))
            }
            return Wallet(
                portableID: portableID, sourcePosition: sourcePosition,
                initialized: initialized, name: name, metadata: metadata, slots: slots
            )
        } catch {
            for index in portableID.indices {
                portableID[index] = 0
            }
            for index in metadata.indices {
                metadata[index].clearSecrets()
            }
            for index in slots.indices {
                slots[index].clearSecrets()
            }
            throw error
        }
    }

    static func decodeSlot(from cursor: inout Cursor) throws -> Slot {
        var fields = [Field]()
        do {
            let role = try cursor.readByte()
            let key = try cursor.readText(allowEmpty: true)
            let fieldCount = Int(try cursor.readByte())
            guard (1 ... 23).contains(fieldCount) else { throw CodecError.invalidMaterial }
            fields.reserveCapacity(fieldCount)
            for _ in 0 ..< fieldCount {
                fields.append(Field(id: try cursor.readByte(), value: try cursor.readValue()))
            }
            return Slot(role: role, key: key, fields: fields)
        } catch {
            for index in fields.indices {
                fields[index].clearSecrets()
            }
            throw error
        }
    }
}

extension IOSPortableWalletSemanticMaterial {
    struct Writer {
        var bytes = [UInt8]()

        mutating func write(_ value: UInt8) throws {
            guard bytes.count < maxBytes else { throw CodecError.invalidMaterial }
            bytes.append(value)
        }

        mutating func write(_ value: [UInt8]) throws {
            guard value.count <= maxBytes - bytes.count else { throw CodecError.invalidMaterial }
            bytes.append(contentsOf: value)
        }

        mutating func writeUInt16(_ value: Int) throws {
            guard (0 ... 0xFFFF).contains(value) else { throw CodecError.invalidMaterial }
            try write(UInt8((value >> 8) & 0xFF))
            try write(UInt8(value & 0xFF))
        }

        mutating func writeUInt32(_ value: UInt32) throws {
            try write(UInt8((value >> 24) & 0xFF))
            try write(UInt8((value >> 16) & 0xFF))
            try write(UInt8((value >> 8) & 0xFF))
            try write(UInt8(value & 0xFF))
        }

        mutating func writeValue(_ value: [UInt8]) throws {
            try writeUInt16(value.count)
            try write(value)
        }

        mutating func writeText(_ value: String) throws {
            try writeValue(Array(value.utf8))
        }

        mutating func erase() {
            for index in bytes.indices {
                bytes[index] = 0
            }
        }
    }

    struct Cursor {
        var bytes: [UInt8]
        var offset = 0

        var isAtEnd: Bool { offset == bytes.count }
        var remaining: Int { bytes.count - offset }

        mutating func read(_ count: Int) throws -> [UInt8] {
            guard count >= 0, count <= remaining else { throw CodecError.invalidMaterial }
            defer { offset += count }
            return Array(bytes[offset ..< offset + count])
        }

        mutating func readByte() throws -> UInt8 {
            guard remaining >= 1 else { throw CodecError.invalidMaterial }
            defer { offset += 1 }
            return bytes[offset]
        }

        mutating func readUInt16() throws -> Int {
            let high = Int(try readByte())
            let low = Int(try readByte())
            return high << 8 | low
        }

        mutating func readUInt32() throws -> UInt32 {
            let first = UInt32(try readByte())
            let second = UInt32(try readByte())
            let third = UInt32(try readByte())
            let fourth = UInt32(try readByte())
            return first << 24 | second << 16 | third << 8 | fourth
        }

        mutating func readBoolean() throws -> Bool {
            let value = try readByte()
            guard value <= 1 else { throw CodecError.invalidMaterial }
            return value == 1
        }

        mutating func readValue(maximum: Int = maxSecret) throws -> [UInt8] {
            let size = try readUInt16()
            guard size <= maximum, size <= remaining else { throw CodecError.invalidMaterial }
            return try read(size)
        }

        mutating func readText(allowEmpty: Bool) throws -> String {
            try strictText(readValue(maximum: maxText), allowEmpty: allowEmpty)
        }

        mutating func erase() {
            for index in bytes.indices {
                bytes[index] = 0
            }
        }
    }
}
