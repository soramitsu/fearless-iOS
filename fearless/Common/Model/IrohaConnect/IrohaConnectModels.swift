import Foundation
import SSFUtils

// Wallet side of the current Iroha Connect v1 protocol: the one Torii relays on Taira and that
// `@iroha/iroha-js/connect-browser` and `@iroha/connect-widget` speak on the app side. Ported from the web
// wallet (fearless-wallet-web PR #1122, `iroha-connect-service/wire.ts`); the unit tests replay vectors that
// the web implementation and the upstream app SDK produced.

enum IrohaConnectError: Error, Equatable {
    case invalidLink(String)
    case retiredLink
    case unknownNetwork
    case networkUnavailable
    case wrongNode
    case invalidFrame(String)

    /// The stable code the web wallet uses for the same refusal.
    var code: String {
        switch self {
        case .invalidLink:
            return "iroha_connect_invalid_link"
        case .retiredLink:
            return "iroha_connect_retired_link"
        case .unknownNetwork:
            return "iroha_connect_unknown_network"
        case .networkUnavailable:
            return "iroha_connect_network_unavailable"
        case .wrongNode:
            return "iroha_connect_wrong_node"
        case .invalidFrame:
            return "iroha_connect_invalid_frame"
        }
    }
}

extension IrohaConnectError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "This IrohaConnect link is invalid. Create a new connection in the app."
        case .retiredLink:
            return "This app uses an old version of IrohaConnect. Ask the app to update."
        case .unknownNetwork:
            return "This IrohaConnect link is for a network Fearless doesn't support."
        case .networkUnavailable:
            return "IrohaConnect for SORA Nexus isn't available yet."
        case .wrongNode:
            return "This IrohaConnect link uses an unknown node, so Fearless didn't connect."
        case .invalidFrame:
            return "The app sent an invalid IrohaConnect message, so Fearless ended the session."
        }
    }
}

enum IrohaConnectLimits {
    static let uriBytes = 4096
    static let frameBytes = 2 * 1024 * 1024
    static let transactionBytes = 1024 * 1024
    static let rawBytes = 64 * 1024
    static let accountIDBytes = 1024
    static let appNameBytes = 128
    static let appURLBytes = 2048
    static let iconHashBytes = 256
    static let reasonBytes = 1024
    static let codeBytes = 128
    static let domainTagBytes = 256
    static let permissionEntries = 32
    static let permissionEntryBytes = 256
}

/// A checksummed NetworkId literal (`hash:<64 upper-case hex>#<CRC-16 hex>`) and its 32 marked hash bytes.
struct IrohaConnectNetworkID: Equatable {
    static let byteCount = 32

    /// Genesis of the deployed Taira ledger (2026-10-22 reset), as pinned by the web wallet.
    static let taira = IrohaConnectNetworkID(
        literal: "hash:4978D0BD15FC32B834672B27BBD8A03653B1DF060A1EEE7E9374D29AF3886D91#6774",
        bytes: Data([
            0x49, 0x78, 0xD0, 0xBD, 0x15, 0xFC, 0x32, 0xB8,
            0x34, 0x67, 0x2B, 0x27, 0xBB, 0xD8, 0xA0, 0x36,
            0x53, 0xB1, 0xDF, 0x06, 0x0A, 0x1E, 0xEE, 0x7E,
            0x93, 0x74, 0xD2, 0x9A, 0xF3, 0x88, 0x6D, 0x91
        ])
    )

    let literal: String
    let bytes: Data

    static func parse(_ literal: String) throws -> IrohaConnectNetworkID {
        let invalid = IrohaConnectError.invalidLink("network_id is not a canonical checksummed NetworkId")
        let components = literal.split(separator: "#", omittingEmptySubsequences: false)
        guard components.count == 2,
              components[0].hasPrefix("hash:"),
              components[0].utf8.count == 69,
              components[1].utf8.count == 4 else {
            throw invalid
        }

        let body = String(components[0].dropFirst(5))
        let checksum = String(components[1])
        let upperHex = Set("0123456789ABCDEF".utf8)
        guard body.utf8.allSatisfy(upperHex.contains),
              checksum.utf8.allSatisfy(upperHex.contains),
              let bytes = Data(irohaConnectHex: body),
              bytes.count == byteCount,
              bytes[bytes.count - 1] & 1 == 1,
              crc16Literal("hash:\(body)") == checksum else {
            throw invalid
        }

        return IrohaConnectNetworkID(literal: literal, bytes: bytes)
    }

    /// CRC-16/CCITT-FALSE over the literal's tag and body, the checksum NetworkId literals carry.
    static func crc16Literal(_ text: String) -> String {
        var crc: UInt16 = 0xFFFF
        for byte in Data(text.utf8) {
            crc ^= UInt16(byte) << 8
            for _ in 0 ..< 8 {
                crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return String(format: "%04X", crc)
    }
}

/// A network the wallet accepts Connect links for, with the only Torii it relays through.
struct IrohaConnectProfile: Equatable {
    enum Network: String, Equatable {
        case taira
        case nexus
    }

    let network: Network
    let displayName: String
    /// Nil while the network has no pinned genesis NetworkId; links for it are refused.
    let networkID: IrohaConnectNetworkID?
    let toriiBaseURL: String
    let networkPrefix: Int

    static let taira = IrohaConnectProfile(
        network: .taira,
        displayName: "Taira Testnet",
        networkID: .taira,
        toriiBaseURL: "https://taira.sora.org",
        networkPrefix: UniversalWalletRegistry.taira.chainDiscriminant
    )

    // SORA Nexus stays refused until its genesis NetworkId is pinned in the wallet's network catalog.
    static let nexus = IrohaConnectProfile(
        network: .nexus,
        displayName: "SORA Nexus",
        networkID: nil,
        toriiBaseURL: "https://minamoto.sora.org",
        networkPrefix: UniversalWalletRegistry.nexus.chainDiscriminant
    )

    static let all = [taira, nexus]
}

/// A parsed `iroha://connect` or `irohaconnect://connect` wallet invitation.
struct IrohaConnectWalletURI: Equatable {
    private static let fields = ["sid", "network_id", "app_pk", "nonce", "node", "v", "role", "token", "relay"]
    private static let retiredFields: Set<String> = ["chain_id"]
    private static let schemes = ["iroha", "irohaconnect"]

    let scheme: String
    let profile: IrohaConnectProfile
    let networkID: IrohaConnectNetworkID
    let sessionIDLiteral: String
    let sessionID: Data
    let appPublicKey: Data
    let nonce: Data
    let token: String
    let relayToken: String
    let webSocketURL: URL
    let webSocketSubprotocol: String

    static func parse(_ url: URL) throws -> IrohaConnectWalletURI {
        try parse(url.absoluteString)
    }

    static func parse(_ literal: String) throws -> IrohaConnectWalletURI {
        guard !literal.isEmpty,
              literal.unicodeScalars.first.map({ !CharacterSet.whitespacesAndNewlines.contains($0) }) == true,
              literal.unicodeScalars.last.map({ !CharacterSet.whitespacesAndNewlines.contains($0) }) == true else {
            throw IrohaConnectError.invalidLink("link must be a non-empty string without surrounding whitespace")
        }
        guard literal.utf8.count <= IrohaConnectLimits.uriBytes else {
            throw IrohaConnectError.invalidLink("link is too long")
        }
        guard let scheme = schemes.first(where: { literal.hasPrefix("\($0)://connect?") }) else {
            throw IrohaConnectError.invalidLink("link must use iroha://connect or irohaconnect://connect")
        }
        guard let components = URLComponents(string: literal),
              components.host == "connect",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.path.isEmpty,
              components.fragment == nil else {
            throw IrohaConnectError.invalidLink("link authority, path, or fragment is not canonical")
        }

        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if retiredFields.contains(item.name) {
                throw IrohaConnectError.retiredLink
            }
            guard fields.contains(item.name) else {
                throw IrohaConnectError.invalidLink("unexpected link field \(item.name)")
            }
            guard values[item.name] == nil else {
                throw IrohaConnectError.invalidLink("duplicate link field \(item.name)")
            }
            guard let value = item.value, !value.isEmpty else {
                throw IrohaConnectError.invalidLink("empty link field \(item.name)")
            }
            values[item.name] = value
        }
        for name in fields where values[name] == nil {
            throw IrohaConnectError.invalidLink("link is missing \(name)")
        }
        guard values["v"] == "1" else {
            throw IrohaConnectError.invalidLink("v must be exactly 1")
        }
        guard values["role"] == "wallet" else {
            throw IrohaConnectError.invalidLink("role must be exactly wallet")
        }

        let networkID = try IrohaConnectNetworkID.parse(values["network_id"] ?? "")
        let node = values["node"] ?? ""
        guard let profile = IrohaConnectProfile.all.first(where: { $0.networkID == networkID }) else {
            let sanitizedNode = node.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
            let nexus = IrohaConnectProfile.nexus
            if nexus.networkID == nil, sanitizedNode == nexus.toriiBaseURL {
                throw IrohaConnectError.networkUnavailable
            }
            throw IrohaConnectError.unknownNetwork
        }
        guard node == profile.toriiBaseURL else {
            throw IrohaConnectError.wrongNode
        }

        let sessionIDLiteral = values["sid"] ?? ""
        let sessionID = try decodeCanonicalBase64URL(sessionIDLiteral, label: "sid", count: 32)
        let appPublicKey = try decodeCanonicalBase64URL(values["app_pk"] ?? "", label: "app_pk", count: 32)
        let nonce = try decodeCanonicalBase64URL(values["nonce"] ?? "", label: "nonce", count: 16)
        let token = values["token"] ?? ""
        let relayToken = values["relay"] ?? ""
        _ = try decodeCanonicalBase64URL(token, label: "token", count: 32)
        _ = try decodeCanonicalBase64URL(relayToken, label: "relay", count: 32)
        guard deriveSessionID(networkID: networkID.bytes, appPublicKey: appPublicKey, nonce: nonce) == sessionID else {
            throw IrohaConnectError.invalidLink("sid is not bound to network_id, app_pk, and nonce")
        }

        var webSocket = URLComponents()
        webSocket.scheme = "wss"
        webSocket.host = URL(string: profile.toriiBaseURL)?.host
        webSocket.path = "/v1/connect/ws"
        webSocket.queryItems = [
            URLQueryItem(name: "sid", value: sessionIDLiteral),
            URLQueryItem(name: "role", value: "wallet")
        ]
        guard profile.toriiBaseURL.hasPrefix("https://"), let webSocketURL = webSocket.url else {
            throw IrohaConnectError.invalidLink("IrohaConnect relays must use HTTPS Torii roots")
        }

        return IrohaConnectWalletURI(
            scheme: scheme,
            profile: profile,
            networkID: networkID,
            sessionIDLiteral: sessionIDLiteral,
            sessionID: sessionID,
            appPublicKey: appPublicKey,
            nonce: nonce,
            token: token,
            relayToken: relayToken,
            webSocketURL: webSocketURL,
            webSocketSubprotocol: tokenProtocol(token)
        )
    }

    /// `iroha-connect.token.v1.<base64url(token)>`, the WebSocket subprotocol carrying the wallet token.
    static func tokenProtocol(_ token: String) -> String {
        "iroha-connect.token.v1.\(Data(token.utf8).irohaConnectBase64URL)"
    }

    /// blake2b-256("iroha-connect|sid|" || NetworkId || app_pk || nonce): the sid binds the network and app key.
    static func deriveSessionID(networkID: Data, appPublicKey: Data, nonce: Data) -> Data? {
        try? (Data("iroha-connect|sid|".utf8) + networkID + appPublicKey + nonce).blake2b32()
    }

    private static func decodeCanonicalBase64URL(_ value: String, label: String, count: Int) throws -> Data {
        let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)
        guard !value.isEmpty, value.utf8.allSatisfy(alphabet.contains) else {
            throw IrohaConnectError.invalidLink("\(label) must be unpadded base64url")
        }
        let standard = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padded = standard + String(repeating: "=", count: (4 - standard.utf8.count % 4) % 4)
        guard let decoded = Data(base64Encoded: padded),
              decoded.count == count,
              decoded.irohaConnectBase64URL == value else {
            throw IrohaConnectError.invalidLink("\(label) must be the canonical spelling of \(count) bytes")
        }
        guard decoded.contains(where: { $0 != 0 }) else {
            throw IrohaConnectError.invalidLink("\(label) must not be all zeroes")
        }
        return decoded
    }
}

struct IrohaConnectPermissions: Equatable {
    let methods: [String]
    let events: [String]
    let resources: [String]?
}

struct IrohaConnectAppMetadata: Equatable {
    let name: String
    let url: String?
    let iconHash: String?
}

enum IrohaConnectDirection: UInt32, Equatable {
    case appToWallet = 0
    case walletToApp = 1
}

enum IrohaConnectRole: UInt32, Equatable {
    case app = 0
    case wallet = 1
}

struct IrohaConnectOpenFrame: Equatable {
    let appPublicKey: Data
    let appMetadata: IrohaConnectAppMetadata?
    let networkID: Data
    let permissions: IrohaConnectPermissions?
    /// The exact `Option<Permissions>` field bytes, echoed in the approval.
    let permissionsField: Data
}

enum IrohaConnectControl: Equatable {
    case open(IrohaConnectOpenFrame)
    case ping(UInt64)
    case pong(UInt64)
    case close(who: IrohaConnectRole, code: UInt16, reason: String, retryable: Bool)
    case reject(code: UInt16, codeID: String, reason: String)
    case serverEvent
}

struct IrohaConnectFrame: Equatable {
    enum Kind: Equatable {
        case control(IrohaConnectControl)
        case ciphertext(Data)
    }

    let direction: IrohaConnectDirection
    let sequence: UInt64
    let kind: Kind
}

/// A decrypted app-to-wallet payload.
enum IrohaConnectAppPayload: Equatable {
    case signRequestTransaction(Data)
    case signRequestRaw(domainTag: String, bytes: Data)
    case close(who: IrohaConnectRole, code: UInt16, reason: String, retryable: Bool)
    case reject(code: UInt16, codeID: String, reason: String)
    case unknown(tag: UInt32)
}

/// A wallet-to-app payload sealed into a ciphertext frame.
enum IrohaConnectWalletPayload: Equatable {
    case signResultOK(signature: Data)
    case signResultError(code: String, message: String)
    case close(code: UInt16, reason: String, retryable: Bool)
}

extension Data {
    init?(irohaConnectHex value: String) {
        guard value.utf8.count.isMultiple(of: 2) else {
            return nil
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(value.utf8.count / 2)
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

    var irohaConnectHex: String {
        map { String(format: "%02x", $0) }.joined()
    }

    var irohaConnectBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
