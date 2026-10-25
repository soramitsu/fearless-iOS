import CryptoKit
import Foundation
import TonSwift
import TweetNacl

enum LegacyTonConnectError: LocalizedError {
    case invalidRequest
    case invalidSession
    case unsupportedRequest
    case expiredRequest
    case unavailableWallet
    case unavailableBridge
    case transportFailed
    case busy

    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "The TonConnect request is invalid."
        case .invalidSession: return "This TonConnect session could not be unlocked. Its stored data has been preserved."
        case .unsupportedRequest: return "This TonConnect request is not supported."
        case .expiredRequest: return "This TonConnect request has expired. Request it again in the application."
        case .unavailableWallet: return "Unlock the wallet originally connected to this application and try again."
        case .unavailableBridge: return "The original TonConnect bridge is unavailable. Try again after the TON network loads."
        case .transportFailed: return "The TonConnect bridge could not be reached. Try again."
        case .busy: return "Finish the current TonConnect approval before opening another request."
        }
    }
}

struct LegacyTonConnectSession: Equatable {
    let identifier: String
    let walletId: String
    let clientId: String
    let appUrl: URL
    let name: String
    let iconUrl: URL?
    let publicKey: Data
    let privateKey: Data
    let connectionType: String

    func validated() throws -> LegacyTonConnectSession {
        guard !identifier.isEmpty, !walletId.isEmpty,
              ["http", "js"].contains(connectionType),
              LegacyTonConnectProtocol.origin(appUrl) != nil,
              publicKey.count == 32, privateKey.count == 32,
              try NaclBox.keyPair(fromSecretKey: privateKey).publicKey == publicKey,
              connectionType == "js" || LegacyTonConnectProtocol.clientKey(clientId) != nil else {
            throw LegacyTonConnectError.invalidSession
        }
        return self
    }

    func encrypt(_ message: Data) throws -> Data {
        _ = try validated()
        guard message.count <= LegacyTonConnectProtocol.maximumMessageBytes,
              let recipient = LegacyTonConnectProtocol.clientKey(clientId) else {
            throw LegacyTonConnectError.invalidRequest
        }
        let nonce = try NaclUtil.secureRandomData(count: 24)
        return try nonce + NaclBox.box(message: message, nonce: nonce, publicKey: recipient, secretKey: privateKey)
    }

    func decrypt(_ message: Data, from sender: String) throws -> Data {
        _ = try validated()
        guard sender.lowercased() == clientId.lowercased(),
              let senderKey = LegacyTonConnectProtocol.clientKey(sender),
              (40 ... LegacyTonConnectProtocol.maximumMessageBytes + 40).contains(message.count) else {
            throw LegacyTonConnectError.invalidRequest
        }
        return try NaclBox.open(message: Data(message.dropFirst(24)), nonce: Data(message.prefix(24)), publicKey: senderKey, secretKey: privateKey)
    }
}

struct LegacyTonConnectManifest: Decodable {
    let url: URL
    let name: String
    let iconUrl: URL?

    func validated() throws -> LegacyTonConnectManifest {
        guard LegacyTonConnectProtocol.origin(url) != nil,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.utf8.count <= 256,
              iconUrl.map({ LegacyTonConnectProtocol.origin($0) != nil }) ?? true else {
            throw LegacyTonConnectError.invalidRequest
        }
        return self
    }
}

struct LegacyTonConnectConnectRequest: Decodable {
    struct Item: Decodable {
        let name: String
        let payload: String?
    }

    let manifestUrl: URL
    let items: [Item]

    func validated() throws -> LegacyTonConnectConnectRequest {
        guard LegacyTonConnectProtocol.origin(manifestUrl) != nil,
              (1 ... 2).contains(items.count),
              Set(items.map(\.name)).count == items.count,
              items.contains(where: { $0.name == "ton_addr" }),
              items.allSatisfy({ item in
                  item.name == "ton_addr" ||
                      (item.name == "ton_proof" && item.payload.map { !$0.isEmpty && $0.utf8.count <= 1024 } == true)
              }) else { throw LegacyTonConnectError.invalidRequest }
        return self
    }
}

struct LegacyTonConnectRPCRequest: Decodable {
    let id: String
    let method: String
    let params: [String]

    static func decode(_ data: Data) throws -> LegacyTonConnectRPCRequest {
        guard data.count <= LegacyTonConnectProtocol.maximumMessageBytes else { throw LegacyTonConnectError.invalidRequest }
        let request = try JSONDecoder().decode(Self.self, from: data)
        guard !request.id.isEmpty, request.id.utf8.count <= 128,
              request.params.count <= 1 else { throw LegacyTonConnectError.invalidRequest }
        guard ["sendTransaction", "disconnect"].contains(request.method) else { throw LegacyTonConnectError.unsupportedRequest }
        guard request.method != "sendTransaction" || request.params.count == 1 else { throw LegacyTonConnectError.invalidRequest }
        return request
    }
}

struct LegacyTonConnectTransactionParameters: Decodable {
    struct Message: Decodable {
        let address: String
        let amount: String
        let payload: String?
        let stateInit: String?
    }

    let valid_until: UInt64
    let network: String?
    let from: String?
    let messages: [Message]

    static func decode(_ data: Data, sender: String, network expectedNetwork: String, now: UInt64) throws -> Self {
        guard data.count <= LegacyTonConnectProtocol.maximumMessageBytes,
              ["-239", "-3"].contains(expectedNetwork) else { throw LegacyTonConnectError.invalidRequest }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.valid_until > now else { throw LegacyTonConnectError.expiredRequest }
        let senderAddress = try TonSwift.Address.parse(sender)
        guard value.network == nil || value.network == expectedNetwork,
              (1 ... 4).contains(value.messages.count),
              value.from.map({ (try? TonSwift.Address.parse($0)) == senderAddress }) ?? true else {
            throw LegacyTonConnectError.invalidRequest
        }
        return value
    }
}

enum LegacyTonConnectProtocol {
    static let maximumMessageBytes = 65536

    static func origin(_ url: URL) -> String? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https", let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil else { return nil }
        return "https://" + host + (parts.port.flatMap { $0 == 443 ? nil : ":\($0)" } ?? "")
    }

    static func clientKey(_ text: String) -> Data? {
        guard text.utf8.count == 64, text.utf8.allSatisfy({ (48 ... 57).contains($0) || (65 ... 70).contains($0) || (97 ... 102).contains($0) }) else { return nil }
        let characters = Array(text)
        let bytes = stride(from: 0, to: characters.count, by: 2).compactMap {
            UInt8(String(characters[$0 ... $0 + 1]), radix: 16)
        }
        return bytes.count == 32 ? Data(bytes) : nil
    }

    /// Release-pinned SSFQRService accepted both tc: and /ton-connect links.
    static func canonicalLink(_ url: URL) -> URL? {
        guard url.absoluteString.utf8.count <= maximumMessageBytes else { return nil }
        if url.scheme?.lowercased() == "tc" { return url }
        guard url.path == "/ton-connect",
              ["https", "fearless"].contains(url.scheme?.lowercased() ?? ""),
              let original = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var result = URLComponents()
        result.scheme = "tc"
        result.queryItems = original.queryItems
        return result.url
    }

    static func parseLink(_ url: URL) throws -> (clientId: String, request: LegacyTonConnectConnectRequest) {
        guard url.absoluteString.utf8.count <= maximumMessageBytes,
              let canonical = canonicalLink(url), let parts = URLComponents(url: canonical, resolvingAgainstBaseURL: false) else {
            throw LegacyTonConnectError.invalidRequest
        }
        let query = parts.queryItems ?? []
        guard ["v", "id", "r"].allSatisfy({ key in query.filter { $0.name == key }.count == 1 }),
              query.first(where: { $0.name == "v" })?.value == "2",
              let clientId = query.first(where: { $0.name == "id" })?.value, clientKey(clientId) != nil,
              let text = query.first(where: { $0.name == "r" })?.value else { throw LegacyTonConnectError.invalidRequest }
        let request = try JSONDecoder().decode(LegacyTonConnectConnectRequest.self, from: Data(text.utf8)).validated()
        return (clientId.lowercased(), request)
    }

    static func connectEvent(
        account: LegacyTonAccount, privateKey: Data?, network: String,
        request: LegacyTonConnectConnectRequest, manifest: LegacyTonConnectManifest, timestamp: UInt64
    ) throws -> Data {
        _ = try request.validated()
        _ = try manifest.validated()
        guard ["-239", "-3"].contains(network), let domain = manifest.url.host else { throw LegacyTonConnectError.invalidRequest }
        let address = try TonSwift.Address.parse(account.address)
        let stateInit = try WalletV4R2(publicKey: account.publicKey).stateInit
        let builder = Builder()
        try stateInit.storeTo(builder: builder)
        var items: [[String: Any]] = [[
            "name": "ton_addr", "address": address.toRaw(), "network": network,
            "publicKey": account.publicKey.map { String(format: "%02x", $0) }.joined(),
            "walletStateInit": try builder.endCell().toBoc().base64EncodedString()
        ]]
        if let proof = request.items.first(where: { $0.name == "ton_proof" }), let payload = proof.payload {
            guard let privateKey else { throw LegacyTonConnectError.unavailableWallet }
            let validated = try account.validatedPrivateKey(privateKey)
            let message = proofDigest(address: address, domain: domain, payload: payload, timestamp: timestamp)
            let signature = try NaclSign.signDetached(message: message, secretKey: validated)
            items.append(["name": "ton_proof", "proof": [
                "timestamp": timestamp, "domain": ["lengthBytes": domain.utf8.count, "value": domain],
                "payload": payload, "signature": signature.base64EncodedString()
            ]])
        }
        return try JSONSerialization.data(withJSONObject: [
            "event": "connect", "id": timestamp,
            "payload": ["items": items, "device": [
                "platform": "iphone", "appName": "Fearless", "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                "maxProtocolVersion": 2,
                "features": [["name": "SendTransaction", "maxMessages": 4]]
            ]]
        ])
    }

    static func proofDigest(address: TonSwift.Address, domain: String, payload: String, timestamp: UInt64) -> Data {
        var workchain = Int32(address.workchain).bigEndian
        var domainLength = UInt32(domain.utf8.count).littleEndian
        var time = timestamp.littleEndian
        var message = Data("ton-proof-item-v2/".utf8)
        message.append(withUnsafeBytes(of: &workchain) { Data($0) })
        message.append(address.hash)
        message.append(withUnsafeBytes(of: &domainLength) { Data($0) })
        message.append(Data(domain.utf8))
        message.append(withUnsafeBytes(of: &time) { Data($0) })
        message.append(Data(payload.utf8))
        return Data(SHA256.hash(data: Data([0xFF, 0xFF]) + Data("ton-connect".utf8) + Data(SHA256.hash(data: message))))
    }

    static func response(id: String, result: String? = nil, errorCode: Int? = nil, message: String = "") throws -> Data {
        if let result {
            return try JSONSerialization.data(withJSONObject: ["id": id, "result": result])
        }
        return try JSONSerialization.data(withJSONObject: ["id": id, "error": ["code": errorCode ?? 0, "message": message]])
    }
}
