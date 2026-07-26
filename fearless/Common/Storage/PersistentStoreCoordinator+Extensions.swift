import Foundation
import CoreData
import CryptoKit
import Darwin

enum CrashConsistentStoreReplacementBoundary: Equatable {
    case preparingMarkerPersisted
    case backupFileCopied(String)
    case committingMarkerPersisted
    case replacementReturned
    case destinationValidated
    case destinationFamilySynced
    case committedMarkerPersisted
    case rollbackMarkerPersisted
    case liveFileRemoved(String)
    case rollbackTemporaryFileCopied(String)
    case rollbackFileInstalled(String)
    case rollbackFamilyVerified
    case cleanupBackupFileRemoved(String)
    case cleanupBackupDirectoryRemoved
    case cleanupMarkerTemporaryRemoved
    case cleanupMarkerRemoved
    case cleanupTransactionDirectoryRemoved
    case cleanupRecoveryRootRemoved
    case transactionCleaned
}

enum CrashConsistentStoreReplacementInterruption: Error {
    /// Test-only fault used to emulate a process disappearing without running
    /// Swift unwinding, rollback, or defer blocks.
    case simulatedProcessDeath
}

enum CrashConsistentStoreReplacementError: LocalizedError {
    case sourceStoreMissing
    case unsafeFile(URL)
    case unsafeDirectory(URL)
    case storeFamilySizeOverflow
    case storeFamilyTooLarge(
        actualByteCount: UInt64,
        maximumByteCount: UInt64
    )
    case insufficientStorageCapacity(
        requiredByteCount: UInt64,
        availableByteCount: UInt64
    )
    case markerMissingForInterruptedStore
    case markerTooLarge
    case invalidMarker
    case familyMismatch
    case backupUnavailable
    case destinationValidationFailed(Error)
    case rollbackFailed(Error, Error)
    case fileSynchronizationFailed(URL, Error)
    case directorySynchronizationFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .sourceStoreMissing:
            return "The SQLite source store is missing"
        case .unsafeFile:
            return "The SQLite replacement transaction contains an unsafe file"
        case .unsafeDirectory:
            return "The SQLite replacement transaction contains an unsafe directory"
        case .storeFamilySizeOverflow:
            return "The SQLite store family size overflowed its bounded counter"
        case let .storeFamilyTooLarge(actualByteCount, maximumByteCount):
            return """
            The SQLite store family uses \(actualByteCount) bytes, exceeding the \
            \(maximumByteCount)-byte migration limit
            """
        case let .insufficientStorageCapacity(
            requiredByteCount,
            availableByteCount
        ):
            return """
            SQLite replacement requires \(requiredByteCount) free bytes, but only \
            \(availableByteCount) bytes are available
            """
        case .markerMissingForInterruptedStore:
            return "An interrupted SQLite replacement is missing its recovery marker"
        case .markerTooLarge:
            return "The SQLite replacement recovery marker is too large"
        case .invalidMarker:
            return "The SQLite replacement recovery marker is invalid"
        case .familyMismatch:
            return "The SQLite store family does not match its durable manifest"
        case .backupUnavailable:
            return "The SQLite rollback family is incomplete or damaged"
        case let .destinationValidationFailed(error):
            return "The replaced SQLite store failed validation: \(error.localizedDescription)"
        case let .rollbackFailed(replacementError, rollbackError):
            return """
            SQLite replacement failed with \(replacementError.localizedDescription), and rollback \
            failed with \(rollbackError.localizedDescription)
            """
        case let .fileSynchronizationFailed(_, error):
            return "Unable to synchronize a SQLite replacement file: \(error.localizedDescription)"
        case let .directorySynchronizationFailed(_, error):
            return "Unable to synchronize a SQLite replacement directory: \(error.localizedDescription)"
        }
    }
}

struct SQLiteStoreFamilyCopyLimits: Equatable {
    static let userStorageProduction = SQLiteStoreFamilyCopyLimits(
        maximumFamilyByteCount: 512 * 1024 * 1024,
        minimumFreeStorageReserveByteCount: 64 * 1024 * 1024
    )
    static let substrateStorageProduction = SQLiteStoreFamilyCopyLimits(
        maximumFamilyByteCount: 4 * 1024 * 1024 * 1024,
        minimumFreeStorageReserveByteCount: 128 * 1024 * 1024
    )

    let maximumFamilyByteCount: UInt64
    let minimumFreeStorageReserveByteCount: UInt64

    init(
        maximumFamilyByteCount: UInt64,
        minimumFreeStorageReserveByteCount: UInt64
    ) {
        self.maximumFamilyByteCount = maximumFamilyByteCount
        self.minimumFreeStorageReserveByteCount =
            minimumFreeStorageReserveByteCount
    }
}

/// Makes a bounded private SQLite-family copy without following sidecar
/// symlinks. Migration callers use the copy as disposable input, so all size
/// and capacity checks happen before the first destination member is created.
enum SQLiteStoreFamilyCopier {
    static let storeFamilySuffixes = ["", "-wal", "-shm", "-journal"]

    private struct SourceMember {
        let sourceURL: URL
        let destinationURL: URL
        let byteCount: UInt64
        let deviceID: UInt64
        let inode: UInt64
    }

    static func copy(
        from sourceStoreURL: URL,
        to destinationStoreURL: URL,
        includingSharedMemory: Bool,
        fileManager: FileManager,
        limits: SQLiteStoreFamilyCopyLimits,
        availableCapacityProvider:
        ((URL) throws -> UInt64)? = nil
    ) throws {
        let sourceStoreURL = sourceStoreURL.standardizedFileURL
        let destinationStoreURL =
            destinationStoreURL.standardizedFileURL
        let destinationDirectoryURL =
            destinationStoreURL.deletingLastPathComponent()

        try requireDirectory(destinationDirectoryURL)

        let capacityProvider =
            availableCapacityProvider ?? { directoryURL in
                try availableCapacity(
                    at: directoryURL,
                    fileManager: fileManager
                )
            }
        var sourceMembers: [SourceMember] = []
        var aggregateByteCount: UInt64 = 0

        for suffix in storeFamilySuffixes {
            let sourceURL = familyURL(
                sourceStoreURL,
                suffix: suffix
            )
            let destinationURL = familyURL(
                destinationStoreURL,
                suffix: suffix
            )

            // Reject stale destination sidecars even when the corresponding
            // source member is absent. Otherwise SQLite could attach data that
            // was never part of the bounded source snapshot.
            guard pathKind(at: destinationURL) == .missing else {
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(destinationURL)
            }

            if suffix == "-shm", !includingSharedMemory {
                continue
            }

            switch pathKind(at: sourceURL) {
            case .missing:
                if suffix.isEmpty {
                    throw CrashConsistentStoreReplacementError
                        .sourceStoreMissing
                }
                continue
            case .regularFile:
                break
            case .directory, .symbolicLink, .other:
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(sourceURL)
            }

            let values = try lstatValues(at: sourceURL)
            let addition =
                aggregateByteCount.addingReportingOverflow(
                    values.byteCount
                )
            guard !addition.overflow else {
                throw CrashConsistentStoreReplacementError
                    .storeFamilySizeOverflow
            }
            aggregateByteCount = addition.partialValue
            guard
                aggregateByteCount <=
                limits.maximumFamilyByteCount
            else {
                throw CrashConsistentStoreReplacementError
                    .storeFamilyTooLarge(
                        actualByteCount: aggregateByteCount,
                        maximumByteCount:
                        limits.maximumFamilyByteCount
                    )
            }

            sourceMembers.append(
                SourceMember(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    byteCount: values.byteCount,
                    deviceID: values.deviceID,
                    inode: values.inode
                )
            )
        }

        let requiredCapacity =
            aggregateByteCount.addingReportingOverflow(
                limits.minimumFreeStorageReserveByteCount
            )
        guard !requiredCapacity.overflow else {
            throw CrashConsistentStoreReplacementError
                .storeFamilySizeOverflow
        }
        let availableByteCount = try capacityProvider(
            destinationDirectoryURL
        )
        guard
            availableByteCount >= requiredCapacity.partialValue
        else {
            throw CrashConsistentStoreReplacementError
                .insufficientStorageCapacity(
                    requiredByteCount:
                    requiredCapacity.partialValue,
                    availableByteCount: availableByteCount
                )
        }

        for member in sourceMembers {
            let sourceBeforeCopy = try lstatValues(
                at: member.sourceURL
            )
            guard
                sourceBeforeCopy.byteCount == member.byteCount,
                sourceBeforeCopy.deviceID == member.deviceID,
                sourceBeforeCopy.inode == member.inode,
                pathKind(at: member.destinationURL) == .missing
            else {
                throw CrashConsistentStoreReplacementError
                    .familyMismatch
            }

            try fileManager.copyItem(
                at: member.sourceURL,
                to: member.destinationURL
            )

            let sourceAfterCopy = try lstatValues(
                at: member.sourceURL
            )
            let destinationValues = try lstatValues(
                at: member.destinationURL
            )
            guard
                pathKind(at: member.destinationURL) ==
                .regularFile,
                sourceAfterCopy.byteCount == member.byteCount,
                sourceAfterCopy.deviceID == member.deviceID,
                sourceAfterCopy.inode == member.inode,
                destinationValues.byteCount == member.byteCount
            else {
                throw CrashConsistentStoreReplacementError
                    .familyMismatch
            }
        }
    }

    private enum PathKind: Equatable {
        case missing
        case regularFile
        case directory
        case symbolicLink
        case other
    }

    private static func availableCapacity(
        at directoryURL: URL,
        fileManager: FileManager
    ) throws -> UInt64 {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        if let values = try? directoryURL.resourceValues(forKeys: keys) {
            if
                let capacity =
                values.volumeAvailableCapacityForImportantUsage,
                capacity >= 0 {
                return UInt64(capacity)
            }
            if
                let capacity = values.volumeAvailableCapacity,
                capacity >= 0 {
                return UInt64(capacity)
            }
        }

        let attributes = try fileManager.attributesOfFileSystem(
            forPath: directoryURL.path
        )
        if
            let freeSize = attributes[.systemFreeSize] as? NSNumber,
            freeSize.int64Value >= 0 {
            return freeSize.uint64Value
        }

        throw CocoaError(.fileReadUnknown)
    }

    private static func requireDirectory(_ url: URL) throws {
        guard pathKind(at: url) == .directory else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(url)
        }
    }

    private static func familyURL(
        _ storeURL: URL,
        suffix: String
    ) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }

    private static func pathKind(at url: URL) -> PathKind {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            return errno == ENOENT ? .missing : .other
        }

        switch fileStatus.st_mode & S_IFMT {
        case S_IFREG:
            return .regularFile
        case S_IFDIR:
            return .directory
        case S_IFLNK:
            return .symbolicLink
        default:
            return .other
        }
    }

    private static func lstatValues(
        at url: URL
    ) throws -> (
        byteCount: UInt64,
        deviceID: UInt64,
        inode: UInt64
    ) {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            throw POSIXError(
                POSIXErrorCode(rawValue: errno) ?? .EIO
            )
        }
        guard
            fileStatus.st_size >= 0,
            fileStatus.st_mode & S_IFMT == S_IFREG
        else {
            throw CrashConsistentStoreReplacementError
                .unsafeFile(url)
        }

        return (
            byteCount: UInt64(fileStatus.st_size),
            deviceID: UInt64(truncatingIfNeeded: fileStatus.st_dev),
            inode: UInt64(truncatingIfNeeded: fileStatus.st_ino)
        )
    }
}

/// Replaces a closed SQLite store family while retaining a bounded, durable
/// rollback transaction beside the database. The transaction is deliberately
/// independent of the application's temporary directory so an iOS process
/// termination cannot discard the sole recovery copy.
final class CrashConsistentStoreReplacer {
    private enum TransactionState: String, Codable {
        case preparing
        case committing
        case rollingBack
        case committed
    }

    private struct FamilyMember: Codable, Equatable {
        let suffix: String
        let byteCount: UInt64
        let sha256: String
    }

    private struct Marker: Codable {
        let schemaVersion: Int
        let storeFileName: String
        var state: TransactionState
        let originalFamily: [FamilyMember]
        var committedFamily: [FamilyMember]?
    }

    private enum PathKind {
        case missing
        case regularFile
        case directory
        case symbolicLink
        case other
    }

    private struct FileIdentity: Hashable {
        let deviceID: UInt64
        let inode: UInt64
    }

    private struct StrictJSONField {
        let key: String
        let keyUsedEscape: Bool
        let value: StrictJSONValue
    }

    private indirect enum StrictJSONValue {
        case object([StrictJSONField])
        case array([StrictJSONValue])
        case string(String)
        case number(String)
        case boolean(Bool)
        case null
    }

    private struct StrictJSONParser {
        private static let maximumDepth = 8
        private static let maximumCollectionCount = 32

        private let bytes: [UInt8]
        private var index = 0

        init(data: Data) {
            bytes = Array(data)
        }

        mutating func parse() throws -> StrictJSONValue {
            skipWhitespace()
            let value = try parseValue(depth: 0)
            skipWhitespace()
            guard index == bytes.count else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
            return value
        }

        private mutating func parseValue(
            depth: Int
        ) throws -> StrictJSONValue {
            guard
                depth <= Self.maximumDepth,
                let byte = currentByte
            else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }

            switch byte {
            case 0x7B:
                return .object(try parseObject(depth: depth + 1))
            case 0x5B:
                return .array(try parseArray(depth: depth + 1))
            case 0x22:
                return .string(try parseString().value)
            case 0x2D, 0x30 ... 0x39:
                return .number(try parseNumber())
            case 0x74:
                try consumeLiteral([0x74, 0x72, 0x75, 0x65])
                return .boolean(true)
            case 0x66:
                try consumeLiteral([
                    0x66, 0x61, 0x6C, 0x73, 0x65
                ])
                return .boolean(false)
            case 0x6E:
                try consumeLiteral([0x6E, 0x75, 0x6C, 0x6C])
                return .null
            default:
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
        }

        private mutating func parseObject(
            depth: Int
        ) throws -> [StrictJSONField] {
            try consume(0x7B)
            skipWhitespace()
            if consumeIfPresent(0x7D) {
                return []
            }

            var fields: [StrictJSONField] = []
            while true {
                guard fields.count < Self.maximumCollectionCount else {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }

                let key = try parseString()
                skipWhitespace()
                try consume(0x3A)
                skipWhitespace()
                let value = try parseValue(depth: depth)
                fields.append(
                    StrictJSONField(
                        key: key.value,
                        keyUsedEscape: key.usedEscape,
                        value: value
                    )
                )

                skipWhitespace()
                if consumeIfPresent(0x7D) {
                    return fields
                }

                try consume(0x2C)
                skipWhitespace()
            }
        }

        private mutating func parseArray(
            depth: Int
        ) throws -> [StrictJSONValue] {
            try consume(0x5B)
            skipWhitespace()
            if consumeIfPresent(0x5D) {
                return []
            }

            var values: [StrictJSONValue] = []
            while true {
                guard values.count < Self.maximumCollectionCount else {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }

                values.append(try parseValue(depth: depth))
                skipWhitespace()
                if consumeIfPresent(0x5D) {
                    return values
                }

                try consume(0x2C)
                skipWhitespace()
            }
        }

        private mutating func parseString() throws -> (
            value: String,
            usedEscape: Bool
        ) {
            guard currentByte == 0x22 else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }

            let startIndex = index
            index += 1
            var usedEscape = false

            while let byte = currentByte {
                switch byte {
                case 0x22:
                    index += 1
                    let token = Data(bytes[startIndex ..< index])
                    do {
                        return (
                            try JSONDecoder().decode(
                                String.self,
                                from: token
                            ),
                            usedEscape
                        )
                    } catch {
                        throw CrashConsistentStoreReplacementError
                            .invalidMarker
                    }
                case 0x5C:
                    usedEscape = true
                    index += 1
                    guard let escapedByte = currentByte else {
                        throw CrashConsistentStoreReplacementError
                            .invalidMarker
                    }

                    switch escapedByte {
                    case 0x22, 0x2F, 0x5C, 0x62, 0x66, 0x6E,
                         0x72, 0x74:
                        index += 1
                    case 0x75:
                        index += 1
                        guard index + 4 <= bytes.count else {
                            throw CrashConsistentStoreReplacementError
                                .invalidMarker
                        }
                        for hexByte in bytes[index ..< index + 4] {
                            guard Self.isHexadecimal(hexByte) else {
                                throw CrashConsistentStoreReplacementError
                                    .invalidMarker
                            }
                        }
                        index += 4
                    default:
                        throw CrashConsistentStoreReplacementError
                            .invalidMarker
                    }
                case 0x00 ... 0x1F:
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                default:
                    index += 1
                }
            }

            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        private mutating func parseNumber() throws -> String {
            let startIndex = index

            if consumeIfPresent(0x2D) {
                guard currentByte != nil else {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }
            }

            if consumeIfPresent(0x30) {
                if
                    let byte = currentByte,
                    Self.isDigit(byte) {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }
            } else {
                guard
                    let byte = currentByte,
                    (0x31 ... 0x39).contains(byte)
                else {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }
                index += 1
                while
                    let byte = currentByte,
                    Self.isDigit(byte) {
                    index += 1
                }
            }

            if consumeIfPresent(0x2E) {
                guard
                    let byte = currentByte,
                    Self.isDigit(byte)
                else {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }
                while
                    let byte = currentByte,
                    Self.isDigit(byte) {
                    index += 1
                }
            }

            if
                currentByte == 0x65 ||
                currentByte == 0x45 {
                index += 1
                if currentByte == 0x2B || currentByte == 0x2D {
                    index += 1
                }
                guard
                    let byte = currentByte,
                    Self.isDigit(byte)
                else {
                    throw CrashConsistentStoreReplacementError
                        .invalidMarker
                }
                while
                    let byte = currentByte,
                    Self.isDigit(byte) {
                    index += 1
                }
            }

            return String(
                decoding: bytes[startIndex ..< index],
                as: UTF8.self
            )
        }

        private mutating func consumeLiteral(
            _ literal: [UInt8]
        ) throws {
            guard
                index + literal.count <= bytes.count,
                Array(bytes[index ..< index + literal.count]) ==
                literal
            else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
            index += literal.count
        }

        private mutating func consume(_ byte: UInt8) throws {
            guard consumeIfPresent(byte) else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
        }

        private mutating func consumeIfPresent(
            _ byte: UInt8
        ) -> Bool {
            guard currentByte == byte else {
                return false
            }
            index += 1
            return true
        }

        private mutating func skipWhitespace() {
            while
                let byte = currentByte,
                byte == 0x20 ||
                byte == 0x09 ||
                byte == 0x0A ||
                byte == 0x0D {
                index += 1
            }
        }

        private var currentByte: UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        private static func isDigit(_ byte: UInt8) -> Bool {
            (0x30 ... 0x39).contains(byte)
        }

        private static func isHexadecimal(_ byte: UInt8) -> Bool {
            (0x30 ... 0x39).contains(byte) ||
                (0x41 ... 0x46).contains(byte) ||
                (0x61 ... 0x66).contains(byte)
        }
    }

    static let storeFamilySuffixes = ["", "-wal", "-shm", "-journal"]
    static let defaultMaximumStoreFamilyByteCount: UInt64 =
        4 * 1024 * 1024 * 1024
    static let defaultMinimumFreeStorageReserveByteCount: UInt64 =
        64 * 1024 * 1024

    private static let markerSchemaVersion = 1
    private static let maximumMarkerByteCount: UInt64 = 64 * 1024
    private static let digestChunkByteCount = 1024 * 1024
    private static let recoveryRootName = ".FearlessStoreReplacement"

    let storeURL: URL
    let transactionDirectoryURL: URL

    private let fileManager: FileManager
    private let storeReplacer: (URL, URL) throws -> Void
    private let boundaryHook: (CrashConsistentStoreReplacementBoundary) throws -> Void
    private let maximumStoreFamilyByteCount: UInt64
    private let minimumFreeStorageReserveByteCount: UInt64
    private let availableCapacityProvider: (URL) throws -> UInt64

    private var databaseDirectoryURL: URL {
        storeURL.deletingLastPathComponent()
    }

    private var recoveryRootURL: URL {
        transactionDirectoryURL.deletingLastPathComponent()
    }

    private var backupDirectoryURL: URL {
        transactionDirectoryURL.appendingPathComponent(
            "OriginalStoreFamily",
            isDirectory: true
        )
    }

    private var markerURL: URL {
        transactionDirectoryURL.appendingPathComponent("transaction.json")
    }

    private var markerTemporaryURL: URL {
        transactionDirectoryURL.appendingPathComponent(
            "transaction.json.pending"
        )
    }

    var hasPendingTransaction: Bool {
        pathKind(at: transactionDirectoryURL) != .missing
    }

    init(
        storeURL: URL,
        fileManager: FileManager,
        storeReplacer: @escaping (URL, URL) throws -> Void,
        boundaryHook: @escaping (
            CrashConsistentStoreReplacementBoundary
        ) throws -> Void = { _ in },
        maximumStoreFamilyByteCount: UInt64 =
            CrashConsistentStoreReplacer
                .defaultMaximumStoreFamilyByteCount,
        minimumFreeStorageReserveByteCount: UInt64 =
            CrashConsistentStoreReplacer
                .defaultMinimumFreeStorageReserveByteCount,
        availableCapacityProvider: ((URL) throws -> UInt64)? = nil
    ) {
        self.storeURL = storeURL.standardizedFileURL
        self.fileManager = fileManager
        self.storeReplacer = storeReplacer
        self.boundaryHook = boundaryHook
        self.maximumStoreFamilyByteCount =
            maximumStoreFamilyByteCount
        self.minimumFreeStorageReserveByteCount =
            minimumFreeStorageReserveByteCount
        self.availableCapacityProvider =
            availableCapacityProvider ?? { directoryURL in
                let keys: Set<URLResourceKey> = [
                    .volumeAvailableCapacityForImportantUsageKey,
                    .volumeAvailableCapacityKey
                ]
                if
                    let values = try? directoryURL.resourceValues(
                        forKeys: keys
                    ) {
                    if
                        let capacity =
                        values
                            .volumeAvailableCapacityForImportantUsage,
                            capacity >= 0 {
                        return UInt64(capacity)
                    }

                    if
                        let capacity =
                        values.volumeAvailableCapacity,
                        capacity >= 0 {
                        return UInt64(capacity)
                    }
                }

                let attributes = try fileManager
                    .attributesOfFileSystem(
                        forPath: directoryURL.path
                    )
                if
                    let freeSize =
                    attributes[.systemFreeSize] as? NSNumber,
                    freeSize.int64Value >= 0 {
                    return freeSize.uint64Value
                }

                throw CocoaError(.fileReadUnknown)
            }

        let pathDigest = SHA256.hash(
            data: Data(self.storeURL.path.utf8)
        ).prefix(12).map {
            String(format: "%02x", $0)
        }.joined()
        let safeStoreName = self.storeURL.lastPathComponent.map {
            $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_"
                ? String($0)
                : "_"
        }.joined()
        let boundedStoreName = String(safeStoreName.prefix(80))
        transactionDirectoryURL = self.storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.recoveryRootName, isDirectory: true)
            .appendingPathComponent(
                "\(boundedStoreName)-\(pathDigest)",
                isDirectory: true
            )
    }

    func liveStoreExistsSafely() throws -> Bool {
        try requireSafeDatabaseDirectory()

        switch pathKind(at: storeURL) {
        case .regularFile:
            for suffix in Self.storeFamilySuffixes.dropFirst() {
                let sidecarURL = familyURL(
                    storeURL: storeURL,
                    suffix: suffix
                )

                switch pathKind(at: sidecarURL) {
                case .missing, .regularFile:
                    continue
                case .directory, .symbolicLink, .other:
                    throw CrashConsistentStoreReplacementError
                        .unsafeFile(sidecarURL)
                }
            }

            return true
        case .missing:
            let hasOrphanSidecar = Self.storeFamilySuffixes
                .dropFirst()
                .contains {
                    pathKind(
                        at: familyURL(
                            storeURL: storeURL,
                            suffix: $0
                        )
                    ) != .missing
                }

            guard !hasOrphanSidecar else {
                throw CrashConsistentStoreReplacementError
                    .markerMissingForInterruptedStore
            }

            return false
        case .directory, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeFile(storeURL)
        }
    }

    func reconcile(
        validateCommittedStore: (URL) throws -> Void
    ) throws {
        try requireSafeDatabaseDirectory()

        switch pathKind(at: transactionDirectoryURL) {
        case .missing:
            try removeRecoveryRootIfEmpty()
            return
        case .directory:
            break
        case .regularFile, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(transactionDirectoryURL)
        }

        guard pathKind(at: markerURL) != .missing else {
            try reconcileMarkerlessTransaction()
            return
        }

        let marker = try readMarker()
        try requireSafeTransactionTree(
            for: marker,
            verifyBackupContents: false
        )
        try removeMarkerTemporaryIfPresent()

        switch marker.state {
        case .preparing:
            if try family(at: storeURL, matches: marker.originalFamily) {
                try removeTransaction(
                    using: marker,
                    verifyBackupContents: false
                )
            } else {
                try restoreOriginalFamily(using: marker)
            }
        case .committing:
            try restoreOriginalFamily(using: marker)
        case .rollingBack:
            if try family(at: storeURL, matches: marker.originalFamily) {
                try removeTransaction(
                    using: marker,
                    verifyBackupContents: false
                )
            } else {
                try restoreOriginalFamily(using: marker)
            }
        case .committed:
            do {
                guard
                    let committedFamily = marker.committedFamily,
                    try family(at: storeURL, matches: committedFamily)
                else {
                    throw CrashConsistentStoreReplacementError.familyMismatch
                }

                try validateCommittedStoreUsingPrivateCopy(
                    committedFamily,
                    validateCommittedStore: validateCommittedStore
                )
            } catch is CrashConsistentStoreReplacementInterruption {
                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            } catch {
                if Self.isRetryableCapacityError(error) {
                    // A committed live family and its rollback copy are both
                    // still durable. Leave the transaction intact so a later
                    // launch can validate it after the user frees space.
                    throw error
                }

                try restoreOriginalFamily(using: marker)
                return
            }

            try removeTransaction(using: marker)
        }
    }

    func replaceStore(
        with stagedStoreURL: URL,
        validateDestination: (URL) throws -> Void
    ) throws {
        let stagedStoreURL = stagedStoreURL.standardizedFileURL
        try reconcile(validateCommittedStore: validateDestination)
        try requireSafeDatabaseDirectory()
        let stagedFamily = try validateStagedStoreFamily(
            at: stagedStoreURL
        )

        let originalFamily = try manifest(
            for: storeURL,
            requiringMainStore: true
        )
        try requireCapacity(
            forAdditionalByteCount:
            try aggregateByteCount(of: originalFamily),
            at: databaseDirectoryURL
        )
        var marker = Marker(
            schemaVersion: Self.markerSchemaVersion,
            storeFileName: storeURL.lastPathComponent,
            state: .preparing,
            originalFamily: originalFamily,
            committedFamily: nil
        )
        var commitDurablyRecorded = false

        try createTransactionDirectory()
        try persist(marker)
        try boundaryHook(.preparingMarkerPersisted)
        try createBackupDirectory()

        do {
            try copyOriginalFamily(originalFamily)

            guard try family(at: backupStoreURL, matches: originalFamily) else {
                throw CrashConsistentStoreReplacementError.backupUnavailable
            }

            marker.state = .committing
            try persist(marker)
            try boundaryHook(.committingMarkerPersisted)

            guard
                try validateStagedStoreFamily(
                    at: stagedStoreURL
                ) == stagedFamily
            else {
                throw CrashConsistentStoreReplacementError
                    .familyMismatch
            }
            try storeReplacer(storeURL, stagedStoreURL)
            try boundaryHook(.replacementReturned)

            do {
                try validateDestination(storeURL)
            } catch {
                throw CrashConsistentStoreReplacementError
                    .destinationValidationFailed(error)
            }
            try boundaryHook(.destinationValidated)

            try synchronizeFamily(at: storeURL)
            try boundaryHook(.destinationFamilySynced)

            marker.state = .committed
            marker.committedFamily = try manifest(
                for: storeURL,
                requiringMainStore: true
            )
            try persist(marker)
            commitDurablyRecorded = true
            try boundaryHook(.committedMarkerPersisted)

            try removeTransaction(using: marker)
        } catch is CrashConsistentStoreReplacementInterruption {
            throw CrashConsistentStoreReplacementInterruption
                .simulatedProcessDeath
        } catch {
            let replacementError = error

            guard !commitDurablyRecorded else {
                throw replacementError
            }

            do {
                if try family(at: backupStoreURL, matches: originalFamily) {
                    try restoreOriginalFamily(using: marker)
                } else if try family(at: storeURL, matches: originalFamily) {
                    try removeTransaction(
                        using: marker,
                        verifyBackupContents: false
                    )
                } else {
                    throw CrashConsistentStoreReplacementError.backupUnavailable
                }
            } catch is CrashConsistentStoreReplacementInterruption {
                throw CrashConsistentStoreReplacementInterruption
                    .simulatedProcessDeath
            } catch {
                throw CrashConsistentStoreReplacementError.rollbackFailed(
                    replacementError,
                    error
                )
            }

            throw replacementError
        }
    }

    private var backupStoreURL: URL {
        backupDirectoryURL.appendingPathComponent(storeURL.lastPathComponent)
    }

    private func createTransactionDirectory() throws {
        switch pathKind(at: recoveryRootURL) {
        case .missing:
            try fileManager.createDirectory(
                at: recoveryRootURL,
                withIntermediateDirectories: false
            )
            try synchronizeDirectory(databaseDirectoryURL)
        case .directory:
            break
        case .regularFile, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(recoveryRootURL)
        }

        guard pathKind(at: transactionDirectoryURL) == .missing else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(transactionDirectoryURL)
        }

        try fileManager.createDirectory(
            at: transactionDirectoryURL,
            withIntermediateDirectories: false
        )
        try synchronizeDirectory(recoveryRootURL)
    }

    private func createBackupDirectory() throws {
        guard pathKind(at: backupDirectoryURL) == .missing else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(backupDirectoryURL)
        }
        try fileManager.createDirectory(
            at: backupDirectoryURL,
            withIntermediateDirectories: false
        )
        try synchronizeDirectory(transactionDirectoryURL)
    }

    private func copyOriginalFamily(
        _ originalFamily: [FamilyMember]
    ) throws {
        for member in originalFamily {
            let sourceURL = familyURL(
                storeURL: storeURL,
                suffix: member.suffix
            )
            let destinationURL = familyURL(
                storeURL: backupStoreURL,
                suffix: member.suffix
            )

            try requireRegularFile(sourceURL)
            guard pathKind(at: destinationURL) == .missing else {
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try synchronizeFile(destinationURL)
            try synchronizeDirectory(backupDirectoryURL)

            guard
                try familyMember(
                    at: destinationURL,
                    suffix: member.suffix,
                    expectedByteCount: member.byteCount
                ) == member
            else {
                throw CrashConsistentStoreReplacementError.familyMismatch
            }

            try boundaryHook(.backupFileCopied(member.suffix))
        }
    }

    private func restoreOriginalFamily(
        using originalMarker: Marker
    ) throws {
        guard
            try family(
                at: backupStoreURL,
                matches: originalMarker.originalFamily
            )
        else {
            throw CrashConsistentStoreReplacementError.backupUnavailable
        }

        var marker = originalMarker
        marker.state = .rollingBack
        marker.committedFamily = nil
        try persist(marker)
        try boundaryHook(.rollbackMarkerPersisted)

        for suffix in Self.storeFamilySuffixes {
            let liveURL = familyURL(storeURL: storeURL, suffix: suffix)

            switch pathKind(at: liveURL) {
            case .missing:
                continue
            case .regularFile:
                try fileManager.removeItem(at: liveURL)
                try synchronizeDirectory(databaseDirectoryURL)
                try boundaryHook(.liveFileRemoved(suffix))
            case .directory, .symbolicLink, .other:
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(liveURL)
            }
        }

        for member in marker.originalFamily {
            let backupURL = familyURL(
                storeURL: backupStoreURL,
                suffix: member.suffix
            )
            let liveURL = familyURL(
                storeURL: storeURL,
                suffix: member.suffix
            )
            let temporaryURL = databaseDirectoryURL.appendingPathComponent(
                ".\(liveURL.lastPathComponent).fearless-rollback"
            )

            try removeSafeTemporaryFileIfPresent(at: temporaryURL)
            try fileManager.copyItem(at: backupURL, to: temporaryURL)
            try synchronizeFile(temporaryURL)
            guard
                try familyMember(
                    at: temporaryURL,
                    suffix: member.suffix,
                    expectedByteCount: member.byteCount
                ) == member
            else {
                throw CrashConsistentStoreReplacementError.familyMismatch
            }
            try synchronizeDirectory(databaseDirectoryURL)
            try boundaryHook(
                .rollbackTemporaryFileCopied(member.suffix)
            )

            try fileManager.moveItem(at: temporaryURL, to: liveURL)
            try synchronizeDirectory(databaseDirectoryURL)
            try boundaryHook(.rollbackFileInstalled(member.suffix))
        }

        guard try family(at: storeURL, matches: marker.originalFamily) else {
            throw CrashConsistentStoreReplacementError.familyMismatch
        }
        try boundaryHook(.rollbackFamilyVerified)

        try removeTransaction(using: marker)
    }

    private func removeSafeTemporaryFileIfPresent(at url: URL) throws {
        switch pathKind(at: url) {
        case .missing:
            return
        case .regularFile:
            try fileManager.removeItem(at: url)
            try synchronizeDirectory(databaseDirectoryURL)
        case .directory, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError.unsafeFile(url)
        }
    }

    private func removeTransaction(
        using marker: Marker,
        verifyBackupContents: Bool = true
    ) throws {
        try requireSafeTransactionTree(
            for: marker,
            verifyBackupContents: verifyBackupContents
        )

        if pathKind(at: backupDirectoryURL) == .directory {
            for member in marker.originalFamily {
                let backupURL = familyURL(
                    storeURL: backupStoreURL,
                    suffix: member.suffix
                )

                switch pathKind(at: backupURL) {
                case .missing:
                    continue
                case .regularFile:
                    if verifyBackupContents {
                        guard
                            try familyMember(
                                at: backupURL,
                                suffix: member.suffix,
                                expectedByteCount:
                                member.byteCount
                            ) == member
                        else {
                            throw CrashConsistentStoreReplacementError
                                .familyMismatch
                        }
                    }
                    try fileManager.removeItem(at: backupURL)
                    try synchronizeDirectory(backupDirectoryURL)
                    try boundaryHook(
                        .cleanupBackupFileRemoved(member.suffix)
                    )
                case .directory, .symbolicLink, .other:
                    throw CrashConsistentStoreReplacementError
                        .unsafeFile(backupURL)
                }
            }

            guard
                try fileManager.contentsOfDirectory(
                    at: backupDirectoryURL,
                    includingPropertiesForKeys: nil,
                    options: []
                ).isEmpty
            else {
                throw CrashConsistentStoreReplacementError
                    .invalidMarker
            }
            try fileManager.removeItem(at: backupDirectoryURL)
            try synchronizeDirectory(transactionDirectoryURL)
            try boundaryHook(.cleanupBackupDirectoryRemoved)
        }

        try removeMarkerTemporaryIfPresent()

        try requireRegularFile(markerURL)
        try fileManager.removeItem(at: markerURL)
        try synchronizeDirectory(transactionDirectoryURL)
        try boundaryHook(.cleanupMarkerRemoved)

        guard
            try fileManager.contentsOfDirectory(
                at: transactionDirectoryURL,
                includingPropertiesForKeys: nil,
                options: []
            ).isEmpty
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }
        try removeEmptyTransactionDirectory()
    }

    private func removeMarkerTemporaryIfPresent() throws {
        switch pathKind(at: markerTemporaryURL) {
        case .missing:
            return
        case .regularFile:
            let values = try lstatValues(at: markerTemporaryURL)
            guard
                values.byteCount <= Self.maximumMarkerByteCount
            else {
                throw CrashConsistentStoreReplacementError.markerTooLarge
            }
            try fileManager.removeItem(at: markerTemporaryURL)
            try synchronizeDirectory(transactionDirectoryURL)
            try boundaryHook(.cleanupMarkerTemporaryRemoved)
        case .directory, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeFile(markerTemporaryURL)
        }
    }

    private func reconcileMarkerlessTransaction() throws {
        let transactionContents = try fileManager.contentsOfDirectory(
            at: transactionDirectoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        guard try liveStoreExistsSafely() else {
            throw CrashConsistentStoreReplacementError
                .markerMissingForInterruptedStore
        }

        if transactionContents.isEmpty {
            try removeEmptyTransactionDirectory()
            return
        }

        guard
            transactionContents.count == 1,
            transactionContents[0].lastPathComponent ==
            markerTemporaryURL.lastPathComponent
        else {
            throw CrashConsistentStoreReplacementError
                .markerMissingForInterruptedStore
        }

        switch pathKind(at: markerTemporaryURL) {
        case .regularFile:
            let values = try lstatValues(at: markerTemporaryURL)
            guard
                values.byteCount <= Self.maximumMarkerByteCount
            else {
                throw CrashConsistentStoreReplacementError.markerTooLarge
            }
        case .missing:
            throw CrashConsistentStoreReplacementError
                .markerMissingForInterruptedStore
        case .directory, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeFile(markerTemporaryURL)
        }

        try removeMarkerTemporaryIfPresent()
        try removeEmptyTransactionDirectory()
    }

    private func removeEmptyTransactionDirectory() throws {
        guard pathKind(at: transactionDirectoryURL) == .directory else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(transactionDirectoryURL)
        }

        guard
            try fileManager.contentsOfDirectory(
                at: transactionDirectoryURL,
                includingPropertiesForKeys: nil,
                options: []
            ).isEmpty
        else {
            throw CrashConsistentStoreReplacementError
                .markerMissingForInterruptedStore
        }

        try fileManager.removeItem(at: transactionDirectoryURL)
        try synchronizeDirectory(recoveryRootURL)
        try boundaryHook(.cleanupTransactionDirectoryRemoved)
        try removeRecoveryRootIfEmpty()
        try boundaryHook(.transactionCleaned)
    }

    private func removeRecoveryRootIfEmpty() throws {
        switch pathKind(at: recoveryRootURL) {
        case .missing:
            return
        case .directory:
            guard
                try fileManager.contentsOfDirectory(
                    at: recoveryRootURL,
                    includingPropertiesForKeys: nil,
                    options: []
                ).isEmpty
            else {
                return
            }

            try fileManager.removeItem(at: recoveryRootURL)
            try synchronizeDirectory(databaseDirectoryURL)
            try boundaryHook(.cleanupRecoveryRootRemoved)
        case .regularFile, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(recoveryRootURL)
        }
    }

    private func requireSafeTransactionTree(
        for marker: Marker,
        verifyBackupContents: Bool = true
    ) throws {
        guard pathKind(at: transactionDirectoryURL) == .directory else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(transactionDirectoryURL)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: transactionDirectoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        let allowedTopLevelNames: Set<String> = [
            backupDirectoryURL.lastPathComponent,
            markerURL.lastPathComponent,
            markerTemporaryURL.lastPathComponent
        ]
        guard
            contents.allSatisfy({
                allowedTopLevelNames.contains($0.lastPathComponent)
            }),
            contents.contains(where: {
                $0.lastPathComponent == markerURL.lastPathComponent
            })
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        for url in contents {
            switch url.lastPathComponent {
            case backupDirectoryURL.lastPathComponent:
                guard pathKind(at: url) == .directory else {
                    throw CrashConsistentStoreReplacementError
                        .unsafeDirectory(url)
                }
                try requireSafeBackupTree(
                    for: marker,
                    verifyContents: verifyBackupContents
                )
            case markerURL.lastPathComponent:
                try requireRegularFile(url)
            case markerTemporaryURL.lastPathComponent:
                try requireRegularFile(url)
                let values = try lstatValues(at: url)
                guard
                    values.byteCount <=
                    Self.maximumMarkerByteCount
                else {
                    throw CrashConsistentStoreReplacementError
                        .markerTooLarge
                }
            default:
                throw CrashConsistentStoreReplacementError
                    .invalidMarker
            }
        }
    }

    private func requireSafeBackupTree(
        for marker: Marker,
        verifyContents: Bool
    ) throws {
        let expectedMembers = Dictionary(
            uniqueKeysWithValues: marker.originalFamily.map {
                (
                    storeURL.lastPathComponent + $0.suffix,
                    $0
                )
            }
        )
        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        for url in contents {
            guard
                let expectedMember =
                expectedMembers[url.lastPathComponent]
            else {
                throw CrashConsistentStoreReplacementError
                    .invalidMarker
            }
            try requireRegularFile(url)
            if verifyContents {
                guard
                    try familyMember(
                        at: url,
                        suffix: expectedMember.suffix,
                        expectedByteCount:
                        expectedMember.byteCount
                    ) == expectedMember
                else {
                    throw CrashConsistentStoreReplacementError
                        .familyMismatch
                }
            }
        }
    }

    private func persist(_ marker: Marker) throws {
        try validate(marker)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(marker)
        guard data.count <= Self.maximumMarkerByteCount else {
            throw CrashConsistentStoreReplacementError.markerTooLarge
        }
        try validateRawMarkerJSON(data)

        switch pathKind(at: markerURL) {
        case .missing, .regularFile:
            break
        case .directory, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError.unsafeFile(markerURL)
        }

        guard pathKind(at: markerTemporaryURL) == .missing else {
            throw CrashConsistentStoreReplacementError
                .unsafeFile(markerTemporaryURL)
        }
        try data.write(to: markerTemporaryURL)
        try synchronizeFile(markerTemporaryURL)

        guard
            Darwin.rename(
                markerTemporaryURL.path,
                markerURL.path
            ) == 0
        else {
            throw CrashConsistentStoreReplacementError
                .fileSynchronizationFailed(
                    markerURL,
                    POSIXError(
                        POSIXErrorCode(rawValue: errno) ?? .EIO
                    )
                )
        }
        try synchronizeFile(markerURL)
        try synchronizeDirectory(transactionDirectoryURL)
    }

    private func readMarker() throws -> Marker {
        try requireRegularFile(markerURL)
        let values = try lstatValues(at: markerURL)
        guard
            values.byteCount <= Self.maximumMarkerByteCount
        else {
            throw CrashConsistentStoreReplacementError.markerTooLarge
        }

        let data = try Data(contentsOf: markerURL, options: [.mappedIfSafe])
        try validateRawMarkerJSON(data)
        let marker: Marker
        do {
            marker = try JSONDecoder().decode(Marker.self, from: data)
        } catch {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        try validate(marker)
        return marker
    }

    private func validateRawMarkerJSON(_ data: Data) throws {
        var parser = StrictJSONParser(data: data)
        let value = try parser.parse()
        guard case let .object(fields) = value else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        let requiredKeys: Set<String> = [
            "schemaVersion",
            "storeFileName",
            "state",
            "originalFamily"
        ]
        let allowedKeys = requiredKeys.union(["committedFamily"])
        let fieldMap = try exactFieldMap(
            fields,
            allowedKeys: allowedKeys
        )
        guard requiredKeys.isSubset(of: Set(fieldMap.keys)) else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        guard
            let schemaValue = fieldMap["schemaVersion"],
            case let .number(schemaVersion) = schemaValue,
            Int(schemaVersion) != nil,
            let storeFileNameValue = fieldMap["storeFileName"],
            case .string = storeFileNameValue,
            let stateValue = fieldMap["state"],
            case .string = stateValue,
            let originalFamilyValue = fieldMap["originalFamily"],
            case let .array(originalFamily) = originalFamilyValue
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }
        try validateRawFamily(originalFamily)

        if let committedFamily = fieldMap["committedFamily"] {
            guard case let .array(members) = committedFamily else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
            try validateRawFamily(members)
        }
    }

    private func validateRawFamily(
        _ values: [StrictJSONValue]
    ) throws {
        guard
            !values.isEmpty,
            values.count <= Self.storeFamilySuffixes.count
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        for value in values {
            guard case let .object(fields) = value else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
            let fieldMap = try exactFieldMap(
                fields,
                allowedKeys: ["suffix", "byteCount", "sha256"]
            )
            guard
                fieldMap.count == 3,
                let suffixValue = fieldMap["suffix"],
                case .string = suffixValue,
                let byteCountValue = fieldMap["byteCount"],
                case let .number(byteCount) = byteCountValue,
                UInt64(byteCount) != nil,
                let digestValue = fieldMap["sha256"],
                case .string = digestValue
            else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
        }
    }

    private func exactFieldMap(
        _ fields: [StrictJSONField],
        allowedKeys: Set<String>
    ) throws -> [String: StrictJSONValue] {
        guard
            fields.allSatisfy({
                !$0.keyUsedEscape &&
                    allowedKeys.contains($0.key)
            })
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        var result: [String: StrictJSONValue] = [:]
        for field in fields {
            guard result.updateValue(
                field.value,
                forKey: field.key
            ) == nil else {
                throw CrashConsistentStoreReplacementError
                    .invalidMarker
            }
        }
        return result
    }

    private func validate(_ marker: Marker) throws {
        guard
            marker.schemaVersion == Self.markerSchemaVersion,
            marker.storeFileName == storeURL.lastPathComponent
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }

        try validate(marker.originalFamily)

        switch marker.state {
        case .preparing, .committing, .rollingBack:
            guard marker.committedFamily == nil else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
        case .committed:
            guard let committedFamily = marker.committedFamily else {
                throw CrashConsistentStoreReplacementError.invalidMarker
            }
            try validate(committedFamily)
        }
    }

    private func validate(_ family: [FamilyMember]) throws {
        let allowedSuffixes = Set(Self.storeFamilySuffixes)
        let suffixes = family.map(\.suffix)
        let canonicalSuffixes = Self.storeFamilySuffixes.filter {
            suffixes.contains($0)
        }
        var aggregateByteCount: UInt64 = 0
        var aggregateOverflowed = false
        for member in family {
            let addition = aggregateByteCount.addingReportingOverflow(
                member.byteCount
            )
            aggregateByteCount = addition.partialValue
            aggregateOverflowed = aggregateOverflowed || addition.overflow
        }
        guard
            family.count <= Self.storeFamilySuffixes.count,
            !family.isEmpty,
            suffixes.contains(""),
            suffixes == canonicalSuffixes,
            Set(suffixes).count == suffixes.count,
            suffixes.allSatisfy(allowedSuffixes.contains),
            !aggregateOverflowed,
            aggregateByteCount <= maximumStoreFamilyByteCount,
            family.allSatisfy({
                $0.sha256.count == 64 &&
                    $0.sha256.allSatisfy {
                        $0.isHexDigit && !$0.isUppercase
                    }
            })
        else {
            throw CrashConsistentStoreReplacementError.invalidMarker
        }
    }

    private func validateStagedStoreFamily(
        at stagedStoreURL: URL
    ) throws -> [FamilyMember] {
        let standardizedStagedURL =
            stagedStoreURL.standardizedFileURL
        let stagedFamily = try manifest(
            for: standardizedStagedURL,
            requiringMainStore: true
        )
        let forbiddenDirectories = [
            recoveryRootURL,
            transactionDirectoryURL,
            backupDirectoryURL
        ]
        let forbiddenFiles = Self.storeFamilySuffixes.flatMap {
            suffix in

            [
                familyURL(storeURL: storeURL, suffix: suffix),
                familyURL(
                    storeURL: backupStoreURL,
                    suffix: suffix
                )
            ]
        } + [markerURL, markerTemporaryURL]
        var stagedIdentities = Set<FileIdentity>()

        for forbiddenDirectory in forbiddenDirectories {
            guard
                !isWithin(
                    standardizedStagedURL,
                    directory: forbiddenDirectory
                ),
                !isWithin(
                    standardizedStagedURL
                        .resolvingSymlinksInPath(),
                    directory: forbiddenDirectory
                        .resolvingSymlinksInPath()
                )
            else {
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(standardizedStagedURL)
            }
        }

        for member in stagedFamily {
            let stagedMemberURL = familyURL(
                storeURL: standardizedStagedURL,
                suffix: member.suffix
            )
            let stagedIdentity = try lstatValues(
                at: stagedMemberURL
            )
            guard
                stagedIdentities.insert(
                    FileIdentity(
                        deviceID: stagedIdentity.deviceID,
                        inode: stagedIdentity.inode
                    )
                ).inserted
            else {
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(stagedMemberURL)
            }

            for forbiddenURL in forbiddenFiles {
                guard
                    !urlsAlias(stagedMemberURL, forbiddenURL)
                else {
                    throw CrashConsistentStoreReplacementError
                        .unsafeFile(stagedMemberURL)
                }

                guard pathKind(at: forbiddenURL) == .regularFile else {
                    continue
                }
                let forbiddenIdentity = try lstatValues(
                    at: forbiddenURL
                )
                guard
                    stagedIdentity.deviceID !=
                    forbiddenIdentity.deviceID ||
                    stagedIdentity.inode !=
                    forbiddenIdentity.inode
                else {
                    throw CrashConsistentStoreReplacementError
                        .unsafeFile(stagedMemberURL)
                }
            }
        }

        return stagedFamily
    }

    private func validateCommittedStoreUsingPrivateCopy(
        _ committedFamily: [FamilyMember],
        validateCommittedStore: (URL) throws -> Void
    ) throws {
        try requireCapacity(
            forAdditionalByteCount:
            try aggregateByteCount(of: committedFamily),
            at: fileManager.temporaryDirectory
        )

        let validationDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent(
                "FearlessCommittedStoreValidation-\(UUID().uuidString)",
                isDirectory: true
            )
        guard pathKind(at: validationDirectoryURL) == .missing else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(validationDirectoryURL)
        }

        try fileManager.createDirectory(
            at: validationDirectoryURL,
            withIntermediateDirectories: false
        )
        defer {
            try? fileManager.removeItem(at: validationDirectoryURL)
        }

        let validationStoreURL = validationDirectoryURL
            .appendingPathComponent(storeURL.lastPathComponent)
        for member in committedFamily {
            let sourceURL = familyURL(
                storeURL: storeURL,
                suffix: member.suffix
            )
            let destinationURL = familyURL(
                storeURL: validationStoreURL,
                suffix: member.suffix
            )

            try requireRegularFile(sourceURL)
            guard pathKind(at: destinationURL) == .missing else {
                throw CrashConsistentStoreReplacementError
                    .unsafeFile(destinationURL)
            }
            try fileManager.copyItem(
                at: sourceURL,
                to: destinationURL
            )
        }

        guard
            try family(
                at: validationStoreURL,
                matches: committedFamily
            )
        else {
            throw CrashConsistentStoreReplacementError.familyMismatch
        }

        try validateCommittedStore(validationStoreURL)

        guard
            try family(
                at: storeURL,
                matches: committedFamily
            )
        else {
            throw CrashConsistentStoreReplacementError.familyMismatch
        }
    }

    private func urlsAlias(_ lhs: URL, _ rhs: URL) -> Bool {
        let standardizedLHS = lhs.standardizedFileURL
        let standardizedRHS = rhs.standardizedFileURL
        if standardizedLHS == standardizedRHS {
            return true
        }

        return standardizedLHS
            .resolvingSymlinksInPath()
            .standardizedFileURL ==
            standardizedRHS
            .resolvingSymlinksInPath()
            .standardizedFileURL
    }

    private func isWithin(
        _ candidate: URL,
        directory: URL
    ) -> Bool {
        let candidateComponents =
            candidate.standardizedFileURL.pathComponents
        let directoryComponents =
            directory.standardizedFileURL.pathComponents

        guard
            candidateComponents.count >=
            directoryComponents.count
        else {
            return false
        }

        return Array(
            candidateComponents.prefix(directoryComponents.count)
        ) == directoryComponents
    }

    private static func isRetryableCapacityError(
        _ error: Error
    ) -> Bool {
        guard
            let replacementError =
            error as? CrashConsistentStoreReplacementError
        else {
            return false
        }

        if case .insufficientStorageCapacity = replacementError {
            return true
        }

        return false
    }

    private func aggregateByteCount(
        of family: [FamilyMember]
    ) throws -> UInt64 {
        var result: UInt64 = 0

        for member in family {
            let addition = result.addingReportingOverflow(
                member.byteCount
            )
            guard !addition.overflow else {
                throw CrashConsistentStoreReplacementError
                    .storeFamilySizeOverflow
            }
            result = addition.partialValue
            guard result <= maximumStoreFamilyByteCount else {
                throw CrashConsistentStoreReplacementError
                    .storeFamilyTooLarge(
                        actualByteCount: result,
                        maximumByteCount:
                        maximumStoreFamilyByteCount
                    )
            }
        }

        return result
    }

    private func requireCapacity(
        forAdditionalByteCount additionalByteCount: UInt64,
        at directoryURL: URL
    ) throws {
        let requirement =
            additionalByteCount.addingReportingOverflow(
                minimumFreeStorageReserveByteCount
            )
        guard !requirement.overflow else {
            throw CrashConsistentStoreReplacementError
                .storeFamilySizeOverflow
        }

        let availableByteCount = try availableCapacityProvider(
            directoryURL
        )
        guard availableByteCount >= requirement.partialValue else {
            throw CrashConsistentStoreReplacementError
                .insufficientStorageCapacity(
                    requiredByteCount: requirement.partialValue,
                    availableByteCount: availableByteCount
                )
        }
    }

    private func manifest(
        for familyStoreURL: URL,
        requiringMainStore: Bool
    ) throws -> [FamilyMember] {
        var memberSources: [
            (
                url: URL,
                suffix: String,
                byteCount: UInt64
            )
        ] = []
        var aggregateByteCount: UInt64 = 0

        for suffix in Self.storeFamilySuffixes {
            let url = familyURL(
                storeURL: familyStoreURL,
                suffix: suffix
            )

            switch pathKind(at: url) {
            case .missing:
                if suffix.isEmpty, requiringMainStore {
                    throw CrashConsistentStoreReplacementError
                        .sourceStoreMissing
                }
            case .regularFile:
                let values = try lstatValues(at: url)
                let addition =
                    aggregateByteCount.addingReportingOverflow(
                        values.byteCount
                    )
                guard !addition.overflow else {
                    throw CrashConsistentStoreReplacementError
                        .storeFamilySizeOverflow
                }
                aggregateByteCount = addition.partialValue
                guard
                    aggregateByteCount <=
                    maximumStoreFamilyByteCount
                else {
                    throw CrashConsistentStoreReplacementError
                        .storeFamilyTooLarge(
                            actualByteCount:
                            aggregateByteCount,
                            maximumByteCount:
                            maximumStoreFamilyByteCount
                        )
                }
                memberSources.append(
                    (
                        url: url,
                        suffix: suffix,
                        byteCount: values.byteCount
                    )
                )
            case .directory, .symbolicLink, .other:
                throw CrashConsistentStoreReplacementError.unsafeFile(url)
            }
        }

        if
            requiringMainStore,
            !memberSources.contains(where: {
                $0.suffix.isEmpty
            })
        {
            throw CrashConsistentStoreReplacementError.sourceStoreMissing
        }

        // Size every member before hashing any of them. A sparse or corrupt
        // family is therefore rejected in constant memory and without
        // spending unbounded startup time in SHA-256.
        return try memberSources.map {
            try familyMember(
                at: $0.url,
                suffix: $0.suffix,
                expectedByteCount: $0.byteCount
            )
        }
    }

    private func family(
        at familyStoreURL: URL,
        matches expectedFamily: [FamilyMember]
    ) throws -> Bool {
        do {
            let actualFamily = try manifest(
                for: familyStoreURL,
                requiringMainStore: true
            )
            return actualFamily == expectedFamily
        } catch CrashConsistentStoreReplacementError.sourceStoreMissing {
            return false
        }
    }

    private func familyMember(
        at url: URL,
        suffix: String,
        expectedByteCount: UInt64? = nil
    ) throws -> FamilyMember {
        try requireRegularFile(url)
        let valuesBeforeDigest = try lstatValues(at: url)
        guard
            valuesBeforeDigest.byteCount <=
            maximumStoreFamilyByteCount
        else {
            throw CrashConsistentStoreReplacementError
                .storeFamilyTooLarge(
                    actualByteCount:
                    valuesBeforeDigest.byteCount,
                    maximumByteCount:
                    maximumStoreFamilyByteCount
                )
        }
        if let expectedByteCount {
            guard
                valuesBeforeDigest.byteCount == expectedByteCount
            else {
                throw CrashConsistentStoreReplacementError
                    .familyMismatch
            }
        }

        let sha256 = try digest(
            at: url,
            expectedByteCount: valuesBeforeDigest.byteCount
        )
        let valuesAfterDigest = try lstatValues(at: url)
        guard
            valuesAfterDigest.byteCount ==
            valuesBeforeDigest.byteCount,
            valuesAfterDigest.deviceID ==
            valuesBeforeDigest.deviceID,
            valuesAfterDigest.inode ==
            valuesBeforeDigest.inode
        else {
            throw CrashConsistentStoreReplacementError.familyMismatch
        }

        return FamilyMember(
            suffix: suffix,
            byteCount: valuesBeforeDigest.byteCount,
            sha256: sha256
        )
    }

    private func digest(
        at url: URL,
        expectedByteCount: UInt64
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        var remainingByteCount = expectedByteCount
        while remainingByteCount > 0 {
            let readByteCount = Int(
                min(
                    remainingByteCount,
                    UInt64(Self.digestChunkByteCount)
                )
            )
            let data = try handle.read(
                upToCount: readByteCount
            ) ?? Data()
            guard !data.isEmpty else {
                throw CrashConsistentStoreReplacementError.familyMismatch
            }

            hasher.update(data: data)
            remainingByteCount -= UInt64(data.count)
        }

        let unexpectedByte = try handle.read(upToCount: 1) ?? Data()
        guard unexpectedByte.isEmpty else {
            throw CrashConsistentStoreReplacementError.familyMismatch
        }

        return hasher.finalize().map {
            String(format: "%02x", $0)
        }.joined()
    }

    private func synchronizeFamily(at familyStoreURL: URL) throws {
        let family = try manifest(
            for: familyStoreURL,
            requiringMainStore: true
        )

        for member in family {
            try synchronizeFile(
                familyURL(
                    storeURL: familyStoreURL,
                    suffix: member.suffix
                )
            )
        }

        try synchronizeDirectory(
            familyStoreURL.deletingLastPathComponent()
        )
    }

    private func synchronizeFile(_ url: URL) throws {
        do {
            try requireRegularFile(url)
            let handle = try FileHandle(forUpdating: url)
            defer {
                try? handle.close()
            }
            try handle.synchronize()
        } catch {
            throw CrashConsistentStoreReplacementError
                .fileSynchronizationFailed(url, error)
        }
    }

    private func synchronizeDirectory(_ url: URL) throws {
        do {
            guard pathKind(at: url) == .directory else {
                throw CrashConsistentStoreReplacementError
                    .unsafeDirectory(url)
            }

            let descriptor = Darwin.open(url.path, O_RDONLY)
            guard descriptor >= 0 else {
                throw POSIXError(
                    POSIXErrorCode(rawValue: errno) ?? .EIO
                )
            }
            defer {
                _ = Darwin.close(descriptor)
            }

            guard Darwin.fsync(descriptor) == 0 else {
                throw POSIXError(
                    POSIXErrorCode(rawValue: errno) ?? .EIO
                )
            }
        } catch {
            throw CrashConsistentStoreReplacementError
                .directorySynchronizationFailed(url, error)
        }
    }

    private func requireSafeDatabaseDirectory() throws {
        guard pathKind(at: databaseDirectoryURL) == .directory else {
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(databaseDirectoryURL)
        }

        switch pathKind(at: recoveryRootURL) {
        case .missing, .directory:
            return
        case .regularFile, .symbolicLink, .other:
            throw CrashConsistentStoreReplacementError
                .unsafeDirectory(recoveryRootURL)
        }
    }

    private func requireRegularFile(_ url: URL) throws {
        guard pathKind(at: url) == .regularFile else {
            throw CrashConsistentStoreReplacementError.unsafeFile(url)
        }
    }

    private func pathKind(at url: URL) -> PathKind {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            return errno == ENOENT ? .missing : .other
        }

        switch fileStatus.st_mode & S_IFMT {
        case S_IFREG:
            return .regularFile
        case S_IFDIR:
            return .directory
        case S_IFLNK:
            return .symbolicLink
        default:
            return .other
        }
    }

    private func lstatValues(
        at url: URL
    ) throws -> (
        byteCount: UInt64,
        mode: mode_t,
        deviceID: UInt64,
        inode: UInt64
    ) {
        var fileStatus = stat()
        guard Darwin.lstat(url.path, &fileStatus) == 0 else {
            throw POSIXError(
                POSIXErrorCode(rawValue: errno) ?? .EIO
            )
        }

        guard fileStatus.st_size >= 0 else {
            throw CrashConsistentStoreReplacementError.unsafeFile(url)
        }

        return (
            byteCount: UInt64(fileStatus.st_size),
            mode: fileStatus.st_mode,
            deviceID: UInt64(
                truncatingIfNeeded: fileStatus.st_dev
            ),
            inode: UInt64(
                truncatingIfNeeded: fileStatus.st_ino
            )
        )
    }

    private func familyURL(
        storeURL: URL,
        suffix: String
    ) -> URL {
        URL(fileURLWithPath: storeURL.path + suffix)
    }
}

extension NSPersistentStoreCoordinator {
    static func destroyStore(at storeURL: URL) throws {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: NSManagedObjectModel()
        )

        try persistentStoreCoordinator.destroyPersistentStore(
            at: storeURL,
            ofType: NSSQLiteStoreType,
            options: nil
        )
    }

    static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) throws {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: NSManagedObjectModel()
        )

        try persistentStoreCoordinator.replacePersistentStore(
            at: targetURL,
            destinationOptions: nil,
            withPersistentStoreFrom: sourceURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
    }

    static func metadata(at storeURL: URL) -> [String: Any]? {
        try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
    }

    func addPersistentStore(at storeURL: URL, options: [AnyHashable: Any]) throws -> NSPersistentStore {
        try addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
    }
}
