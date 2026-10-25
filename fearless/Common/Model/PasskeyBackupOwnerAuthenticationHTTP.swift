import Foundation

enum PasskeyBackupOwnerAuthenticationError: Error, Equatable {
    case invalidEndpoint
    case malformedResponse
    case invalidChallenge
    case invalidAssertion
    case expiredChallenge
    case responseTooLarge
    case httpStatus(Int)
}

/// A discoverable owner ceremony has no owner hint. Only a server-verified assertion can
/// produce the owner session used by the backup-head reader.
struct PasskeyOwnerAuthChallenge: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    let ceremonyId: String
    let challenge: Data
    let expiresAtUnixSeconds: Int64

    init(ceremonyId: String, challenge: Data, expiresAtUnixSeconds: Int64) throws {
        guard ceremonyId.hasPrefix("ceremony."),
              let decoded = try? PasskeyBackupContract.decodeBase64URL(String(ceremonyId.dropFirst(9))),
              decoded.count == 32,
              challenge.count == 32,
              expiresAtUnixSeconds > 0 else {
            throw PasskeyBackupOwnerAuthenticationError.invalidChallenge
        }
        self.ceremonyId = ceremonyId
        self.challenge = challenge
        self.expiresAtUnixSeconds = expiresAtUnixSeconds
    }

    var description: String {
        "PasskeyOwnerAuthChallenge(<redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

/// Public WebAuthn assertion fields only. No PRF output can enter this type or its JSON.
struct PasskeyBackupOwnerPublicAssertion: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    let credentialID: Data
    let clientDataJSON: Data
    let authenticatorData: Data
    let signature: Data
    let userHandle: Data

    init(
        credentialID: Data, clientDataJSON: Data, authenticatorData: Data,
        signature: Data, userHandle: Data
    ) throws {
        do {
            _ = try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: credentialID, clientDataJSON: clientDataJSON,
                authenticatorData: authenticatorData, signature: signature,
                userHandle: userHandle
            )
        } catch {
            throw PasskeyBackupOwnerAuthenticationError.invalidAssertion
        }
        self.credentialID = credentialID
        self.clientDataJSON = clientDataJSON
        self.authenticatorData = authenticatorData
        self.signature = signature
        self.userHandle = userHandle
    }

    func credentialObject() throws -> [String: Any] {
        let json = try PasskeyCredentialResponseSerializer.assertionJSON(
            credentialID: credentialID, clientDataJSON: clientDataJSON,
            authenticatorData: authenticatorData, signature: signature,
            userHandle: userHandle
        )
        guard let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw PasskeyBackupOwnerAuthenticationError.invalidAssertion
        }
        return object
    }

    var description: String {
        "PasskeyBackupOwnerPublicAssertion(<redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}

protocol PasskeyBackupOwnerAuthenticationSource {
    func begin() async throws -> PasskeyOwnerAuthChallenge
    func complete(
        challenge: PasskeyOwnerAuthChallenge,
        assertion: PasskeyBackupOwnerPublicAssertion
    ) async throws -> PasskeyBackupOwnerSession
}

/// No owner name, Drive account, PRF bytes or wallet key is sent in either request.
final class HTTPPasskeyOwnerAuthSource: PasskeyBackupOwnerAuthenticationSource {
    private static let beginPath = "/api/passkey-backup/v1/owner/authentication/challenge"
    private static let completePath = "/api/passkey-backup/v1/owner/authentication/complete"
    private static let beginBody = Data(#"{"schemaVersion":1,"platform":"ios"}"#.utf8)
    private static let maximumResponseBytes = 8192
    private static let maximumRequestBytes = 65536

    private let beginURL: URL
    private let completeURL: URL
    private let transport: PasskeyBackupHTTPTransport
    private let nowUnixSeconds: () -> Int64

    init(
        baseURL: URL, transport: PasskeyBackupHTTPTransport,
        nowUnixSeconds: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) }
    ) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, !host.isEmpty,
              host == host.lowercased(), components.user == nil, components.password == nil,
              components.port == nil, components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
              baseURL.absoluteString == "https://\(host)" ||
              baseURL.absoluteString == "https://\(host)/",
              let beginURL = URL(string: "https://\(host)\(Self.beginPath)"),
              let completeURL = URL(string: "https://\(host)\(Self.completePath)") else {
            throw PasskeyBackupOwnerAuthenticationError.invalidEndpoint
        }
        self.beginURL = beginURL
        self.completeURL = completeURL
        self.transport = transport
        self.nowUnixSeconds = nowUnixSeconds
    }

    @available(iOS 15.0, macOS 12.0, *)
    convenience init(baseURL: URL = PasskeyBackupReleaseConfig.challengeServiceBaseURL) throws {
        try self.init(
            baseURL: baseURL,
            transport: URLSessionPasskeyBackupHTTPTransport(maximumResponseBytes: Self.maximumResponseBytes)
        )
    }

    func begin() async throws -> PasskeyOwnerAuthChallenge {
        let body = try await post(url: beginURL, body: Self.beginBody)
        do {
            let object = try PasskeyBackupOwnerResponseJSON.parseObject(body)
            guard Set(object.keys) == Set([
                "ceremonyId", "kind", "challenge", "rpId", "platform",
                "subject", "namespace", "userHandle", "expiresAt"
            ]),
                object["kind"] == .string("authentication"),
                object["rpId"] == .string(PasskeyBackupContract.PASSKEY_RP_ID),
                object["platform"] == .string("ios"),
                object["subject"] == .null,
                object["namespace"] == .null,
                object["userHandle"] == .null,
                case let .string(ceremonyId) = object["ceremonyId"],
                case let .string(encodedChallenge) = object["challenge"],
                case let .number(expiresAt) = object["expiresAt"] else {
                throw PasskeyBackupOwnerAuthenticationError.malformedResponse
            }
            let decodedChallenge = try PasskeyBackupContract.decodeBase64URL(encodedChallenge)
            let current = nowUnixSeconds()
            guard current >= 0, current <= Int64.max - 660,
                  expiresAt > current, expiresAt <= current + 300 else {
                throw PasskeyBackupOwnerAuthenticationError.expiredChallenge
            }
            return try PasskeyOwnerAuthChallenge(
                ceremonyId: ceremonyId, challenge: decodedChallenge,
                expiresAtUnixSeconds: expiresAt
            )
        } catch let error as PasskeyBackupOwnerAuthenticationError {
            throw error
        } catch {
            throw PasskeyBackupOwnerAuthenticationError.malformedResponse
        }
    }

    func complete(
        challenge: PasskeyOwnerAuthChallenge,
        assertion: PasskeyBackupOwnerPublicAssertion
    ) async throws -> PasskeyBackupOwnerSession {
        guard challenge.expiresAtUnixSeconds > nowUnixSeconds() else {
            throw PasskeyBackupOwnerAuthenticationError.expiredChallenge
        }
        let request: [String: Any] = try [
            "schemaVersion": 1,
            "ceremonyId": challenge.ceremonyId,
            "credential": assertion.credentialObject()
        ]
        guard JSONSerialization.isValidJSONObject(request) else {
            throw PasskeyBackupOwnerAuthenticationError.invalidAssertion
        }
        let body = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        guard body.count <= Self.maximumRequestBytes else {
            throw PasskeyBackupOwnerAuthenticationError.invalidAssertion
        }
        let response = try await post(url: completeURL, body: body)
        do {
            let object = try PasskeyBackupOwnerResponseJSON.parseObject(response)
            guard Set(object.keys) == Set([
                "sessionToken", "subject", "namespace", "generation", "platform", "expiresAt"
            ]),
                object["platform"] == .string("ios"),
                case let .string(token) = object["sessionToken"],
                case let .string(subject) = object["subject"],
                case let .string(namespace) = object["namespace"],
                case let .number(generation) = object["generation"],
                case let .number(expiresAt) = object["expiresAt"],
                generation >= 0 else {
                throw PasskeyBackupOwnerAuthenticationError.malformedResponse
            }
            let current = nowUnixSeconds()
            guard current >= 0, current <= Int64.max - 660,
                  expiresAt > current, expiresAt <= current + 660 else {
                throw PasskeyBackupOwnerAuthenticationError.malformedResponse
            }
            return try PasskeyBackupOwnerSession(
                token: token, ownerSubject: subject, backupNamespace: namespace,
                generation: generation, platform: "ios", expiresAtUnixSeconds: expiresAt
            )
        } catch {
            throw PasskeyBackupOwnerAuthenticationError.malformedResponse
        }
    }

    private func post(url: URL, body: Data) async throws -> Data {
        try Task.checkCancellation()
        let response = try await transport.execute(PasskeyBackupHTTPRequest(
            method: "POST", url: url,
            headers: ["Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store"],
            body: body
        ))
        try Task.checkCancellation()
        guard response.body.count <= Self.maximumResponseBytes else {
            throw PasskeyBackupOwnerAuthenticationError.responseTooLarge
        }
        guard response.statusCode == 200 else {
            throw PasskeyBackupOwnerAuthenticationError.httpStatus(response.statusCode)
        }
        return response.body
    }
}
