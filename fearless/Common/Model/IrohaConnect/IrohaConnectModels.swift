import Foundation
import SSFUtils

enum IrohaConnectError: LocalizedError, Equatable {
    case invalidURI
    case uriTooLarge
    case unsupportedURIField
    case duplicateURIField
    case missingURIField
    case invalidVersionOrRole
    case invalidBase64URL
    case invalidNetworkID
    case unsupportedNetwork
    case unsupportedNode
    case sessionIDMismatch
    case invalidLength
    case truncated
    case trailingBytes
    case invalidUTF8
    case invalidDirection
    case invalidSequence
    case unsupportedFrameKind
    case unsupportedControl
    case invalidPermissions
    case invalidState
    case authenticationFailed
    case unsupportedRequest
    case invalidAccount
    case invalidSignature
    case messageTooLarge
    case cryptographyFailed

    var errorDescription: String? {
        switch self {
        case .invalidURI,
             .uriTooLarge,
             .unsupportedURIField,
             .duplicateURIField,
             .missingURIField,
             .invalidVersionOrRole,
             .invalidBase64URL,
             .invalidNetworkID,
             .unsupportedNetwork,
             .unsupportedNode,
             .sessionIDMismatch:
            return "This IrohaConnect pairing request is invalid or is not for the canonical Taira network."
        case .invalidPermissions, .unsupportedRequest:
            return "This dApp requested an IrohaConnect capability that Fearless does not allow."
        case .invalidAccount:
            return "The selected wallet does not contain a compatible Taira signing account."
        case .messageTooLarge:
            return "The dApp sent an IrohaConnect signing request that is too large."
        case .authenticationFailed, .invalidSignature, .cryptographyFailed:
            return "Secure IrohaConnect verification failed. Create a fresh pairing request and try again."
        case .invalidLength,
             .truncated,
             .trailingBytes,
             .invalidUTF8,
             .invalidDirection,
             .invalidSequence,
             .unsupportedFrameKind,
             .unsupportedControl,
             .invalidState:
            return "The dApp sent an invalid, unexpected, or replayed IrohaConnect message."
        }
    }
}

struct IrohaConnectNetworkID: Equatable {
    static let byteCount = 32
    static let tairaLiteral = "hash:82531CE8EAE8BFF6BEECA4698BFD13A3BC8BEC5F0EE0D23D428C97FC17AB0F3B#3E94"

    static let taira = IrohaConnectNetworkID(
        literal: tairaLiteral,
        bytes: Data([
            0x82, 0x53, 0x1C, 0xE8, 0xEA, 0xE8, 0xBF, 0xF6,
            0xBE, 0xEC, 0xA4, 0x69, 0x8B, 0xFD, 0x13, 0xA3,
            0xBC, 0x8B, 0xEC, 0x5F, 0x0E, 0xE0, 0xD2, 0x3D,
            0x42, 0x8C, 0x97, 0xFC, 0x17, 0xAB, 0x0F, 0x3B
        ])
    )

    let literal: String
    let bytes: Data

    static func parse(_ literal: String) throws -> IrohaConnectNetworkID {
        let components = literal.split(separator: "#", omittingEmptySubsequences: false)
        guard components.count == 2,
              components[0].hasPrefix("hash:"),
              components[0].count == 69,
              components[1].count == 4 else {
            throw IrohaConnectError.invalidNetworkID
        }

        let body = String(components[0].dropFirst(5))
        let checksum = String(components[1])
        let uppercaseHex = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard body.unicodeScalars.allSatisfy(uppercaseHex.contains),
              checksum.unicodeScalars.allSatisfy(uppercaseHex.contains),
              let bytes = Data(irohaConnectHex: body),
              bytes.count == byteCount,
              bytes[bytes.index(before: bytes.endIndex)] & 1 == 1,
              crc16Literal(tag: "hash", body: body) == checksum else {
            throw IrohaConnectError.invalidNetworkID
        }

        return IrohaConnectNetworkID(literal: literal, bytes: bytes)
    }

    private static func crc16Literal(tag: String, body: String) -> String {
        var crc: UInt16 = 0xFFFF
        for byte in Data("\(tag):\(body)".utf8) {
            crc ^= UInt16(byte) << 8
            for _ in 0 ..< 8 {
                crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }

        return String(format: "%04X", crc)
    }
}

struct IrohaConnectWalletURI: Equatable {
    static let tairaNodeLiteral = "https://taira.sora.org"

    private static let maximumURILength = 4096
    private static let fields: Set<String> = [
        "sid",
        "network_id",
        "app_pk",
        "nonce",
        "node",
        "v",
        "role",
        "token",
        "relay"
    ]

    let sessionIDLiteral: String
    let sessionID: Data
    let networkID: IrohaConnectNetworkID
    let appPublicKey: Data
    let nonce: Data
    let nodeURL: URL
    let webSocketURL: URL
    let token: String
    let relayToken: String
    let webSocketSubprotocol: String

    static func parse(_ url: URL) throws -> IrohaConnectWalletURI {
        try parse(url.absoluteString)
    }

    static func parse(_ literal: String) throws -> IrohaConnectWalletURI {
        guard literal.utf8.count <= maximumURILength else {
            throw IrohaConnectError.uriTooLarge
        }
        guard let components = URLComponents(string: literal),
              let scheme = components.scheme?.lowercased(),
              scheme == "iroha" || scheme == "irohaconnect",
              components.host?.lowercased() == "connect",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.path.isEmpty,
              components.fragment == nil else {
            throw IrohaConnectError.invalidURI
        }

        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard fields.contains(item.name) else {
                throw IrohaConnectError.unsupportedURIField
            }
            guard query[item.name] == nil else {
                throw IrohaConnectError.duplicateURIField
            }
            query[item.name] = item.value ?? ""
        }
        guard query.count == fields.count else {
            throw IrohaConnectError.missingURIField
        }
        guard query["v"] == "1", query["role"] == "wallet" else {
            throw IrohaConnectError.invalidVersionOrRole
        }

        let sessionIDLiteral = try required("sid", in: query)
        let sessionID = try decodeBase64URL(sessionIDLiteral, expectedCount: 32)
        let appPublicKey = try decodeBase64URL(try required("app_pk", in: query), expectedCount: 32)
        let nonce = try decodeBase64URL(try required("nonce", in: query), expectedCount: 16)
        let networkID = try IrohaConnectNetworkID.parse(try required("network_id", in: query))
        guard networkID == .taira else {
            throw IrohaConnectError.unsupportedNetwork
        }

        let nodeLiteral = try required("node", in: query)
        guard nodeLiteral == tairaNodeLiteral,
              let nodeURL = URL(string: tairaNodeLiteral) else {
            throw IrohaConnectError.unsupportedNode
        }

        let token = try required("token", in: query)
        let relayToken = try required("relay", in: query)
        _ = try decodeBase64URL(token, expectedCount: 32)
        _ = try decodeBase64URL(relayToken, expectedCount: 32)

        let expectedSessionID: Data
        do {
            expectedSessionID = try (
                Data("iroha-connect|sid|".utf8) + networkID.bytes + appPublicKey + nonce
            ).blake2b32()
        } catch {
            throw IrohaConnectError.cryptographyFailed
        }
        guard expectedSessionID == sessionID else {
            throw IrohaConnectError.sessionIDMismatch
        }

        var webSocket = URLComponents()
        webSocket.scheme = "wss"
        webSocket.host = "taira.sora.org"
        webSocket.path = "/v1/connect/ws"
        webSocket.queryItems = [
            URLQueryItem(name: "sid", value: sessionIDLiteral),
            URLQueryItem(name: "role", value: "wallet")
        ]
        guard let webSocketURL = webSocket.url else {
            throw IrohaConnectError.invalidURI
        }

        return IrohaConnectWalletURI(
            sessionIDLiteral: sessionIDLiteral,
            sessionID: sessionID,
            networkID: networkID,
            appPublicKey: appPublicKey,
            nonce: nonce,
            nodeURL: nodeURL,
            webSocketURL: webSocketURL,
            token: token,
            relayToken: relayToken,
            webSocketSubprotocol: "iroha-connect.token.v1.\(Data(token.utf8).irohaConnectBase64URL)"
        )
    }

    private static func required(_ field: String, in query: [String: String]) throws -> String {
        guard let value = query[field], !value.isEmpty else {
            throw IrohaConnectError.missingURIField
        }
        return value
    }

    private static func decodeBase64URL(_ value: String, expectedCount: Int) throws -> Data {
        guard !value.isEmpty,
              value.utf8.allSatisfy({
                  ($0 >= 65 && $0 <= 90) ||
                      ($0 >= 97 && $0 <= 122) ||
                      ($0 >= 48 && $0 <= 57) ||
                      $0 == 45 || $0 == 95
              }),
              value.count % 4 != 1 else {
            throw IrohaConnectError.invalidBase64URL
        }

        let base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") + String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let decoded = Data(base64Encoded: base64),
              decoded.count == expectedCount,
              decoded.irohaConnectBase64URL == value else {
            throw IrohaConnectError.invalidBase64URL
        }
        return decoded
    }
}

struct IrohaConnectPermissions: Equatable {
    static let contractCallSignatureDomain = "uranai.irohaconnect.contract-call-signature.v1"
    static let uranaiContractSigning = IrohaConnectPermissions(
        methods: ["sign_raw"],
        events: [],
        resources: [contractCallSignatureDomain]
    )

    let methods: [String]
    let events: [String]
    let resources: [String]?
}

struct IrohaConnectAppMetadata: Equatable {
    let name: String
    let url: URL?
    let iconHash: String?
}

enum IrohaConnectDirection: UInt32, Equatable {
    case appToWallet = 0
    case walletToApp = 1
}

struct IrohaConnectOpenFrame: Equatable {
    let appPublicKey: Data
    let appMetadata: IrohaConnectAppMetadata?
    let networkID: Data
    let permissions: IrohaConnectPermissions?
}

enum IrohaConnectControlFrame: Equatable {
    case open(IrohaConnectOpenFrame)
    case ping(UInt64)
    case pong(UInt64)
}

struct IrohaConnectFrame: Equatable {
    enum Kind: Equatable {
        case control(IrohaConnectControlFrame)
        case ciphertext(Data)
    }

    let sessionID: Data
    let direction: IrohaConnectDirection
    let sequence: UInt64
    let kind: Kind
}

struct IrohaConnectSignRawRequest: Equatable {
    let domain: String
    let message: Data
}

private extension Data {
    init?(irohaConnectHex value: String) {
        guard value.count.isMultiple(of: 2) else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(value.count / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index ..< next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var irohaConnectBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
