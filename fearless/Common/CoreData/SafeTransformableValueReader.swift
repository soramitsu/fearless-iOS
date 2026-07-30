import CoreData
import Foundation
import SQLite3

enum SafeTransformableValueReaderError: LocalizedError, Equatable {
    case objectiveCException
    case unexpectedStoredType

    var errorDescription: String? {
        switch self {
        case .objectiveCException:
            return "A stored value could not be decoded safely"
        case .unexpectedStoredType:
            return "A stored value has an unexpected type"
        }
    }
}

enum SafeObjectiveCExceptionBoundary {
    /// Preserves ordinary Swift errors while converting an Objective-C
    /// exception into the single generic, payload-free storage error.
    static func perform(
        _ operation: @escaping () throws -> Void
    ) throws {
        var operationError: Error?

        do {
            _ = try FearlessObjectiveCExceptionCatcher.performObjectRead {
                do {
                    try operation()
                } catch {
                    operationError = error
                }

                return nil
            }
        } catch {
            throw SafeTransformableValueReaderError.objectiveCException
        }

        if let operationError {
            throw operationError
        }
    }
}

enum SafeTransformableValueReader {
    static func readObject(
        from object: NSManagedObject,
        key: String
    ) throws -> Any? {
        do {
            let value = try FearlessObjectiveCExceptionCatcher.performObjectRead {
                object.value(forKey: key)
            }

            return value is NSNull ? nil : value
        } catch {
            throw SafeTransformableValueReaderError.objectiveCException
        }
    }

    static func read<Value>(
        from object: NSManagedObject,
        key: String,
        as _: Value.Type = Value.self
    ) throws -> Value? {
        let rawValue = try readObject(from: object, key: key)

        guard let rawValue else {
            return nil
        }

        guard let value = rawValue as? Value else {
            throw SafeTransformableValueReaderError.unexpectedStoredType
        }

        return value
    }
}

struct SQLiteTransformableArchiveColumn: Equatable {
    let entityName: String
    let attributeName: String
    let isOptional: Bool
    let valueTransformerName: String?
}

enum SQLiteTransformableArchiveRepairError: LocalizedError, Equatable {
    case invalidLimit
    case unsafeIdentifier
    case databaseUnavailable
    case schemaMismatch(String, String)
    case transformerUnavailable(String, String)
    case sqliteOperationFailed(Int32)
    case repairedValueCountOverflow

    var errorDescription: String? {
        switch self {
        case .invalidLimit:
            return "The transformable archive byte limit is invalid"
        case .unsafeIdentifier:
            return "A transformable archive has an unsafe storage identifier"
        case .databaseUnavailable:
            return "The private Core Data store could not be opened safely"
        case let .schemaMismatch(entityName, attributeName):
            return """
            The private Core Data store is missing the expected \
            \(entityName).\(attributeName) archive column
            """
        case let .transformerUnavailable(entityName, attributeName):
            return """
            The private Core Data store cannot encode an empty \
            \(entityName).\(attributeName) archive
            """
        case .sqliteOperationFailed:
            return "The private Core Data archive repair failed safely"
        case .repairedValueCountOverflow:
            return "The private Core Data archive repair count overflowed"
        }
    }
}

/// Bounds raw transformable BLOBs before Core Data can invoke a value
/// transformer. The caller must pass only model-verified, allowlisted columns
/// from a disposable SQLite store copy.
enum SQLiteTransformableArchivePreflight {
    private static let sqliteTransient = unsafeBitCast(
        -1,
        to: sqlite3_destructor_type.self
    )

    @discardableResult
    static func repairOversizedArchives(
        at storeURL: URL,
        columns: [SQLiteTransformableArchiveColumn],
        maximumArchiveByteCount: Int
    ) throws -> Int {
        guard
            maximumArchiveByteCount >= 0,
            UInt64(maximumArchiveByteCount) <= UInt64(Int64.max)
        else {
            throw SQLiteTransformableArchiveRepairError.invalidLimit
        }

        guard !columns.isEmpty else {
            return 0
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database {
                sqlite3_close_v2(database)
            }
            throw SQLiteTransformableArchiveRepairError
                .databaseUnavailable
        }
        defer {
            sqlite3_close_v2(database)
        }

        sqlite3_extended_result_codes(database, 1)
        try execute("BEGIN IMMEDIATE TRANSACTION", in: database)

        do {
            var repairedValueCount = 0
            for column in columns {
                try validateSchema(
                    for: column,
                    in: database
                )
                let repairedCount = try repairOversizedArchives(
                    in: column,
                    maximumArchiveByteCount:
                    maximumArchiveByteCount,
                    database: database
                )
                let addition = repairedValueCount
                    .addingReportingOverflow(repairedCount)
                guard !addition.overflow else {
                    throw SQLiteTransformableArchiveRepairError
                        .repairedValueCountOverflow
                }
                repairedValueCount = addition.partialValue
            }

            try execute("COMMIT TRANSACTION", in: database)
            return repairedValueCount
        } catch {
            _ = try? execute("ROLLBACK TRANSACTION", in: database)
            throw error
        }
    }

    private static func validateSchema(
        for column: SQLiteTransformableArchiveColumn,
        in database: OpaquePointer
    ) throws {
        let tableName = try physicalIdentifier(
            for: column.entityName
        )
        let columnName = try physicalIdentifier(
            for: column.attributeName
        )

        var tableStatement: OpaquePointer?
        let tableSQL = """
        SELECT COUNT(*) FROM sqlite_master
        WHERE type = 'table' AND name = ?1 COLLATE BINARY
        """
        try prepare(
            tableSQL,
            statement: &tableStatement,
            in: database
        )
        guard let tableStatement else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(SQLITE_INTERNAL)
        }
        defer {
            sqlite3_finalize(tableStatement)
        }

        guard
            sqlite3_bind_text(
                tableStatement,
                1,
                tableName,
                -1,
                sqliteTransient
            ) == SQLITE_OK,
            sqlite3_step(tableStatement) == SQLITE_ROW,
            sqlite3_column_int64(tableStatement, 0) == 1,
            sqlite3_step(tableStatement) == SQLITE_DONE
        else {
            throw SQLiteTransformableArchiveRepairError
                .schemaMismatch(
                    column.entityName,
                    column.attributeName
                )
        }

        let quotedTableName = try quotedIdentifier(tableName)
        var columnStatement: OpaquePointer?
        try prepare(
            "PRAGMA table_info(\(quotedTableName))",
            statement: &columnStatement,
            in: database
        )
        guard let columnStatement else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(SQLITE_INTERNAL)
        }
        defer {
            sqlite3_finalize(columnStatement)
        }

        var matchingColumns = 0
        while true {
            let stepResult = sqlite3_step(columnStatement)
            if stepResult == SQLITE_DONE {
                break
            }
            guard stepResult == SQLITE_ROW else {
                throw SQLiteTransformableArchiveRepairError
                    .sqliteOperationFailed(stepResult)
            }

            guard
                let rawName = sqlite3_column_text(
                    columnStatement,
                    1
                )
            else {
                throw SQLiteTransformableArchiveRepairError
                    .sqliteOperationFailed(SQLITE_CORRUPT)
            }
            let name = String(cString: rawName)
            if name == columnName {
                guard
                    let rawType = sqlite3_column_text(
                        columnStatement,
                        2
                    ),
                    String(cString: rawType).uppercased() == "BLOB"
                else {
                    throw SQLiteTransformableArchiveRepairError
                        .schemaMismatch(
                            column.entityName,
                            column.attributeName
                        )
                }
                matchingColumns += 1
            }
        }

        guard matchingColumns == 1 else {
            throw SQLiteTransformableArchiveRepairError
                .schemaMismatch(
                    column.entityName,
                    column.attributeName
                )
        }
    }

    private static func repairOversizedArchives(
        in column: SQLiteTransformableArchiveColumn,
        maximumArchiveByteCount: Int,
        database: OpaquePointer
    ) throws -> Int {
        let tableName = try quotedIdentifier(
            physicalIdentifier(for: column.entityName)
        )
        let columnName = try quotedIdentifier(
            physicalIdentifier(for: column.attributeName)
        )
        let sql = """
        UPDATE \(tableName)
        SET \(columnName) = ?1
        WHERE \(columnName) IS NOT NULL
          AND (
            typeof(\(columnName)) != 'blob'
            OR length(\(columnName)) > ?2
          )
        """

        var statement: OpaquePointer?
        try prepare(sql, statement: &statement, in: database)
        guard let statement else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(SQLITE_INTERNAL)
        }
        defer {
            sqlite3_finalize(statement)
        }

        let replacementResult: Int32
        if column.isOptional {
            replacementResult = sqlite3_bind_null(statement, 1)
        } else if column.valueTransformerName != nil {
            let replacement = try emptyArchiveData(for: column)
            guard
                replacement.count <= maximumArchiveByteCount
            else {
                throw SQLiteTransformableArchiveRepairError
                    .invalidLimit
            }
            replacementResult = replacement.withUnsafeBytes {
                rawBuffer in

                sqlite3_bind_blob(
                    statement,
                    1,
                    rawBuffer.baseAddress,
                    Int32(rawBuffer.count),
                    sqliteTransient
                )
            }
        } else {
            throw SQLiteTransformableArchiveRepairError
                .transformerUnavailable(
                    column.entityName,
                    column.attributeName
                )
        }

        guard
            replacementResult == SQLITE_OK,
            sqlite3_bind_int64(
                statement,
                2,
                Int64(maximumArchiveByteCount)
            ) == SQLITE_OK
        else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(sqlite3_errcode(database))
        }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(stepResult)
        }

        return Int(sqlite3_changes(database))
    }

    private static func emptyArchiveData(
        for column: SQLiteTransformableArchiveColumn
    ) throws -> Data {
        guard
            let transformerName = column.valueTransformerName,
            let transformer = ValueTransformer(
                forName: NSValueTransformerName(
                    rawValue: transformerName
                )
            ),
            let data = transformer.reverseTransformedValue(
                NSArray()
            ) as? Data
        else {
            throw SQLiteTransformableArchiveRepairError
                .transformerUnavailable(
                    column.entityName,
                    column.attributeName
                )
        }

        return data
    }

    private static func execute(
        _ sql: String,
        in database: OpaquePointer
    ) throws {
        let result = sqlite3_exec(
            database,
            sql,
            nil,
            nil,
            nil
        )
        guard result == SQLITE_OK else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(result)
        }
    }

    private static func prepare(
        _ sql: String,
        statement: inout OpaquePointer?,
        in database: OpaquePointer
    ) throws {
        let result = sqlite3_prepare_v2(
            database,
            sql,
            -1,
            &statement,
            nil
        )
        guard result == SQLITE_OK else {
            throw SQLiteTransformableArchiveRepairError
                .sqliteOperationFailed(result)
        }
    }

    private static func physicalIdentifier(
        for modelIdentifier: String
    ) throws -> String {
        let identifier = "Z\(modelIdentifier.uppercased())"
        guard isSafeIdentifier(identifier) else {
            throw SQLiteTransformableArchiveRepairError
                .unsafeIdentifier
        }
        return identifier
    }

    private static func quotedIdentifier(
        _ identifier: String
    ) throws -> String {
        guard isSafeIdentifier(identifier) else {
            throw SQLiteTransformableArchiveRepairError
                .unsafeIdentifier
        }
        return "\"\(identifier)\""
    }

    private static func isSafeIdentifier(
        _ identifier: String
    ) -> Bool {
        !identifier.isEmpty &&
            identifier.unicodeScalars.allSatisfy {
                scalar in

                let value = scalar.value
                return value == 95 ||
                    (48 ... 57).contains(value) ||
                    (65 ... 90).contains(value)
            }
    }
}
