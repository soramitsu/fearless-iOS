import Foundation

/// The two Drive response schemas contain strings, string arrays and string maps only. A small
/// bounded parser rejects duplicate decoded keys and coercions before interpreting either schema.
enum GoogleDriveGenerationResponse {
    static func requireFileID(_ value: String) throws {
        guard value.range(of: #"\A[A-Za-z0-9_-]{1,256}\z"#, options: .regularExpression) != nil else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
    }

    static func allocatedID(_ data: Data) throws -> String {
        let object = try object(data)
        guard Set(object.keys) == Set(["kind", "space", "ids"]),
              object["kind"] == .string("drive#generatedIds"), object["space"] == .string("appDataFolder"),
              case let .array(ids) = object["ids"], ids.count == 1, case let .string(identifier) = ids[0] else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        try requireFileID(identifier)
        return identifier
    }

    static func metadataSize(_ data: Data, fileID: String, name: String, properties: [String: String]) throws -> Int {
        let object = try object(data)
        guard Set(object.keys) == Set(["id", "name", "mimeType", "spaces", "appProperties", "size"]),
              object["id"] == .string(fileID), object["name"] == .string(name),
              object["mimeType"] == .string("application/octet-stream"),
              object["spaces"] == .array([.string("appDataFolder")]),
              object["appProperties"] == .object(properties.mapValues { .string($0) }),
              case let .string(text) = object["size"], let size = Int(text), String(size) == text,
              (1 ... PasskeyBackupGenerationV1Format.maximumBytes).contains(size) else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        return size
    }

    private indirect enum Value: Equatable {
        case string(String), array([Value]), object([String: Value])
    }

    private static func object(_ data: Data) throws -> [String: Value] {
        guard (1 ... 8192).contains(data.count) else { throw GoogleDrivePasskeyBackupError.malformedResponse }
        var parser = Parser(bytes: Array(data))
        let value = try parser.value(depth: 0)
        parser.whitespace()
        guard parser.index == parser.bytes.count, case let .object(object) = value else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        return object
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0

        mutating func whitespace() {
            while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
        }

        mutating func consume(_ byte: UInt8) -> Bool {
            whitespace()
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        mutating func value(depth: Int) throws -> Value {
            whitespace()
            guard depth <= 2, index < bytes.count else { throw GoogleDrivePasskeyBackupError.malformedResponse }
            if bytes[index] == 34 { return try .string(string()) }
            if consume(123) { return try object(depth: depth) }
            if consume(91) { return try array(depth: depth) }
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }

        private mutating func object(depth: Int) throws -> Value {
            var object: [String: Value] = [:]
            if consume(125) { return .object(object) }
            repeat {
                let key = try string()
                guard object[key] == nil, object.count < 8, consume(58) else {
                    throw GoogleDrivePasskeyBackupError.malformedResponse
                }
                object[key] = try value(depth: depth + 1)
            } while consume(44)
            guard consume(125) else { throw GoogleDrivePasskeyBackupError.malformedResponse }
            return .object(object)
        }

        private mutating func array(depth: Int) throws -> Value {
            var array: [Value] = []
            if consume(93) { return .array(array) }
            repeat {
                guard array.count < 8 else { throw GoogleDrivePasskeyBackupError.malformedResponse }
                array.append(try value(depth: depth + 1))
            } while consume(44)
            guard consume(93) else { throw GoogleDrivePasskeyBackupError.malformedResponse }
            return .array(array)
        }

        mutating func string() throws -> String {
            whitespace()
            let start = index
            guard consume(34) else { throw GoogleDrivePasskeyBackupError.malformedResponse }
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == 34 {
                    let token = Data(bytes[start ..< index])
                    guard let string = try? JSONDecoder().decode(String.self, from: token),
                          string.utf8.count <= 2048 else { throw GoogleDrivePasskeyBackupError.malformedResponse }
                    return string
                }
                if byte == 92 { index += 1 }
            }
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
    }
}
