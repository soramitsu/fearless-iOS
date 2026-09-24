import Foundation

enum PasskeyBackupOwnerHeadHTTPError: Error, Equatable {
    case invalidEndpoint
    case invalidSession
    case malformedResponse
    case responseTooLarge
    case httpStatus(Int)
}

/// Created only from a server-verified owner authentication result. A Google account or a
/// locally cached owner name must never be used to construct recovery authority.
struct PasskeyBackupOwnerSession: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let token: String
    let ownerSubject: String
    let backupNamespace: String

    init(token: String, ownerSubject: String, backupNamespace: String) throws {
        guard token.hasPrefix("session."),
              let decoded = try? PasskeyBackupContract.decodeBase64URL(String(token.dropFirst(8))),
              decoded.count == 32 else {
            throw PasskeyBackupOwnerHeadHTTPError.invalidSession
        }
        do {
            _ = try PasskeyBackupGenerationV1.Context(
                ownerSubject: ownerSubject, backupNamespace: backupNamespace,
                generationId: String(repeating: "A", count: 43), parentHeadRevision: 0,
                parentHeadSha256: nil, keyEpoch: 1,
                storageAccountBinding: String(repeating: "0", count: 64)
            )
        } catch {
            throw PasskeyBackupOwnerHeadHTTPError.invalidSession
        }
        self.token = token
        self.ownerSubject = ownerSubject
        self.backupNamespace = backupNamespace
    }

    var description: String {
        "PasskeyBackupOwnerSession(<redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

protocol PasskeyBackupOwnerHeadSource {
    func readHead(
        session: PasskeyBackupOwnerSession,
        expectedStorageAccountBinding: String
    ) async throws -> PasskeyBackupAuthenticatedHead
}

/// Read-only owner endpoint. The bearer session must come from a freshly verified passkey
/// authentication; this adapter does not create owner sessions or authorize wallet installation.
final class HTTPPasskeyBackupOwnerHeadSource: PasskeyBackupOwnerHeadSource {
    private static let path = "/api/passkey-backup/v1/owner/backup/head"
    private static let body = Data(#"{"schemaVersion":1}"#.utf8)
    private static let maximumResponseBytes = 8192

    private let endpoint: URL
    private let transport: PasskeyBackupHTTPTransport

    init(baseURL: URL, transport: PasskeyBackupHTTPTransport) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, !host.isEmpty,
              host == host.lowercased(), components.user == nil, components.password == nil,
              components.port == nil, components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
              baseURL.absoluteString == "https://\(host)" ||
              baseURL.absoluteString == "https://\(host)/",
              let endpoint = URL(string: "https://\(host)\(Self.path)") else {
            throw PasskeyBackupOwnerHeadHTTPError.invalidEndpoint
        }
        self.endpoint = endpoint
        self.transport = transport
    }

    @available(iOS 15.0, macOS 12.0, *)
    convenience init(baseURL: URL) throws {
        try self.init(
            baseURL: baseURL,
            transport: URLSessionPasskeyBackupHTTPTransport(maximumResponseBytes: Self.maximumResponseBytes)
        )
    }

    func readHead(
        session: PasskeyBackupOwnerSession,
        expectedStorageAccountBinding: String
    ) async throws -> PasskeyBackupAuthenticatedHead {
        try Task.checkCancellation()
        let response = try await transport.execute(PasskeyBackupHTTPRequest(
            method: "POST", url: endpoint,
            headers: [
                "Authorization": "Bearer \(session.token)",
                "Content-Type": "application/json; charset=utf-8",
                "Cache-Control": "no-store"
            ], body: Self.body
        ))
        try Task.checkCancellation()
        guard response.body.count <= Self.maximumResponseBytes else {
            throw PasskeyBackupOwnerHeadHTTPError.responseTooLarge
        }
        guard response.statusCode == 200 else {
            throw PasskeyBackupOwnerHeadHTTPError.httpStatus(response.statusCode)
        }
        return try PasskeyBackupOwnerHeadResponse.decode(
            response.body, session: session,
            expectedStorageAccountBinding: expectedStorageAccountBinding
        )
    }
}

/// Closed, bounded JSON decoding is required before interpreting an authenticated owner head.
/// In particular, duplicate decoded keys must not select different generations on two clients.
private enum PasskeyBackupOwnerHeadResponse {
    private indirect enum Value: Equatable {
        case string(String), number(Int64), object([String: Value]), null
    }

    static func decode(
        _ data: Data, session: PasskeyBackupOwnerSession,
        expectedStorageAccountBinding: String
    ) throws -> PasskeyBackupAuthenticatedHead {
        do {
            guard (1 ... 8192).contains(data.count) else { throw PasskeyBackupOwnerHeadHTTPError.malformedResponse }
            var parser = Parser(bytes: Array(data))
            guard case let .object(root) = try parser.value(depth: 0) else {
                throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
            }
            parser.whitespace()
            guard parser.index == parser.bytes.count,
                  Set(root.keys) == Set(["schemaVersion", "ownerSubject", "backupNamespace", "head", "previous"]),
                  root["schemaVersion"] == .number(1),
                  case let .string(ownerSubject) = root["ownerSubject"],
                  case let .string(backupNamespace) = root["backupNamespace"] else {
                throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
            }
            return try PasskeyBackupAuthenticatedHead(
                ownerSubject: ownerSubject, backupNamespace: backupNamespace,
                head: descriptor(root["head"]), previous: descriptor(root["previous"]),
                expectedOwnerSubject: session.ownerSubject,
                expectedBackupNamespace: session.backupNamespace,
                expectedStorageAccountBinding: expectedStorageAccountBinding
            )
        } catch {
            throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
        }
    }

    private static func descriptor(_ value: Value?) throws -> PasskeyBackupHeadDescriptor? {
        if value == .null {
            return nil
        }
        guard case let .object(object) = value,
              Set(object.keys) == Set([
                  "headRevision", "parentHeadRevision", "parentHeadSha256", "generationId",
                  "bundleSha256", "keyEpoch", "driveFileId", "storageAccountBinding"
              ]),
              case let .string(headRevision) = object["headRevision"],
              case let .string(parentHeadRevision) = object["parentHeadRevision"],
              case let .string(generationId) = object["generationId"],
              case let .string(bundleSha256) = object["bundleSha256"],
              case let .string(keyEpoch) = object["keyEpoch"],
              case let .string(driveFileID) = object["driveFileId"],
              case let .string(storageAccountBinding) = object["storageAccountBinding"] else {
            throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
        }
        let parentDigest: String?
        switch object["parentHeadSha256"] {
        case .null: parentDigest = nil
        case let .string(value): parentDigest = value
        default: throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
        }
        return try PasskeyBackupHeadDescriptor(
            headRevision: decimal(headRevision), parentHeadRevision: decimal(parentHeadRevision),
            parentHeadSha256: parentDigest, generationId: generationId,
            bundleSha256: bundleSha256, keyEpoch: decimal(keyEpoch),
            driveFileID: driveFileID, storageAccountBinding: storageAccountBinding
        )
    }

    private static func decimal(_ text: String) throws -> Int64 {
        guard let value = Int64(text), value >= 0, String(value) == text else {
            throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
        }
        return value
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0

        mutating func whitespace() {
            while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) {
                index += 1
            }
        }

        mutating func consume(_ byte: UInt8) -> Bool {
            whitespace()
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        mutating func value(depth: Int) throws -> Value {
            whitespace()
            guard depth <= 2, index < bytes.count else {
                throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
            }
            if bytes[index] == 34 {
                return try .string(string())
            }
            if consume(123) {
                return try object(depth: depth)
            }
            if bytes[index] == 110, literal("null") {
                return .null
            }
            if (48 ... 57).contains(bytes[index]) {
                return try number()
            }
            throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
        }

        private mutating func object(depth: Int) throws -> Value {
            var object: [String: Value] = [:]
            if consume(125) {
                return .object(object)
            }
            repeat {
                let key = try string()
                guard object[key] == nil, object.count < 8, consume(58) else {
                    throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
                }
                object[key] = try value(depth: depth + 1)
            } while consume(44)
            guard consume(125) else {
                throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
            }
            return .object(object)
        }

        private mutating func number() throws -> Value {
            let start = index
            while index < bytes.count, (48 ... 57).contains(bytes[index]) {
                index += 1
            }
            guard let token = String(bytes: bytes[start ..< index], encoding: .utf8),
                  let parsed = Int64(token), parsed >= 0, String(parsed) == token else {
                throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
            }
            return .number(parsed)
        }

        private mutating func literal(_ text: String) -> Bool {
            let token = Array(text.utf8)
            guard bytes[index...].starts(with: token) else { return false }
            index += token.count
            return true
        }

        private mutating func string() throws -> String {
            whitespace()
            let start = index
            guard consume(34) else { throw PasskeyBackupOwnerHeadHTTPError.malformedResponse }
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == 34 {
                    guard let token = String(bytes: bytes[start ..< index], encoding: .utf8),
                          let value = try? JSONDecoder().decode(String.self, from: Data(token.utf8)),
                          value.utf8.count <= 2048 else {
                        throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
                    }
                    return value
                }
                if byte == 92 {
                    index += 1
                }
            }
            throw PasskeyBackupOwnerHeadHTTPError.malformedResponse
        }
    }
}
