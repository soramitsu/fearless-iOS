import CryptoKit
import Foundation

/// Fetches a URL; tests stand in a fake.
public typealias WalletConnectHTTPFetch = @Sendable (URL) async throws -> (status: Int, body: Data)

/// The Verify service: where a proposal or request really came from, against the URL the dApp claims.
///
/// The relay passes along a signed attestation (ES256, Verify's key) when the dApp registered one. Without one,
/// the service is asked by the message's hash. Any failure leaves the context `unknown`.
public actor VerifyClient {
    public static let defaultServer = "https://verify.walletconnect.org"
    static let trustedServers = ["https://verify.walletconnect.com", defaultServer]
    static let timeout: TimeInterval = 5

    private struct PublicKey {
        let key: P256.Signing.PublicKey
        let expiresAt: Date
    }

    private let fetch: WalletConnectHTTPFetch
    private let now: @Sendable () -> Date
    private var publicKey: PublicKey?

    public init(
        fetch: WalletConnectHTTPFetch? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fetch = fetch ?? VerifyClient.urlSessionFetch
        self.now = now
    }

    static let urlSessionFetch: WalletConnectHTTPFetch = { url in
        var request = URLRequest(url: url)
        request.timeoutInterval = VerifyClient.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                continuation.resume(returning: (status, data ?? Data()))
            }
            task.resume()
        }
    }

    static func trustedServer(_ url: String?) -> String {
        guard let url, trustedServers.contains(url) else {
            return defaultServer
        }
        return url
    }

    static func origin(of url: String) -> String? {
        guard let components = URLComponents(string: url), let scheme = components.scheme, let host = components.host else {
            return nil
        }
        var origin = "\(scheme.lowercased())://\(host.lowercased())"
        if let port = components.port {
            origin += ":\(port)"
        }
        return origin
    }

    /// The verification of a message as the relay delivered it, against the metadata of the dApp that sent it.
    public func context(metadata: AppMetadata, message: String, attestation: String?) async -> VerifyContext {
        let server = Self.trustedServer(metadata.verifyUrl)
        let messageHash = WalletConnectCrypto.messageHash(message)
        var attested: (origin: String, isScam: Bool)?

        if let attestation, !attestation.isEmpty {
            switch await fromAttestation(attestation, messageHash: messageHash) {
            case let .attested(origin, isScam):
                attested = (origin, isScam)
            case .unverifiedOrigin:
                attested = nil
            case .invalid:
                attested = await fromService(server, messageHash: messageHash)
            }
        } else if attestation == nil {
            attested = await fromService(server, messageHash: messageHash)
        }

        guard let attested else {
            return VerifyContext(origin: metadata.url, validation: .unknown, verifyUrl: server)
        }

        let validation: VerifyContext.Validation
        if attested.isScam {
            validation = .scam
        } else if attested.origin == Self.origin(of: metadata.url) {
            validation = .valid
        } else {
            validation = .invalid
        }
        return VerifyContext(origin: attested.origin, validation: validation, verifyUrl: server, isScam: attested.isScam)
    }

    private enum AttestationResult {
        case attested(origin: String, isScam: Bool)
        /// Signed and current, but Verify could not confirm the origin.
        case unverifiedOrigin
        case invalid
    }

    private func fromAttestation(_ token: String, messageHash: String) async -> AttestationResult {
        guard
            let claims = RelayAuth.payload(ofToken: token),
            claims["id"]?.stringValue == messageHash,
            RelayAuth.header(ofToken: token)?["alg"]?.stringValue == "ES256"
        else {
            return .invalid
        }

        for refresh in [false, true] {
            guard let key = await verifyKey(refresh: refresh) else {
                return .invalid
            }
            guard Self.isValidSignature(token: token, key: key) else {
                continue
            }
            guard let expiry = claims["exp"]?.numberValue?.doubleValue, Date(timeIntervalSince1970: expiry) > now() else {
                return .invalid
            }
            guard claims["isVerified"]?.boolValue == true, let origin = claims["origin"]?.stringValue else {
                return .unverifiedOrigin
            }
            return .attested(origin: origin, isScam: claims["isScam"]?.boolValue == true)
        }
        return .invalid
    }

    static func isValidSignature(token: String, key: P256.Signing.PublicKey) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let raw = Base64.decodeURL(String(parts[2])),
            raw.count == 64,
            let signature = try? P256.Signing.ECDSASignature(rawRepresentation: raw)
        else {
            return false
        }
        let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
        return key.isValidSignature(signature, for: signingInput)
    }

    private func verifyKey(refresh: Bool) async -> P256.Signing.PublicKey? {
        if !refresh, let publicKey, publicKey.expiresAt > now() {
            return publicKey.key
        }

        guard
            let url = URL(string: "\(Self.defaultServer)/v3/public-key"),
            let response = try? await fetch(url),
            response.status == 200,
            let json = try? JSONParser.parse(response.body, maxBytes: 65536, maxDepth: 8),
            let jwk = json["publicKey"],
            jwk["kty"]?.stringValue == "EC",
            jwk["crv"]?.stringValue == "P-256",
            let x = jwk["x"]?.stringValue.flatMap(Base64.decodeURL),
            let y = jwk["y"]?.stringValue.flatMap(Base64.decodeURL),
            x.count == 32, y.count == 32,
            let key = try? P256.Signing.PublicKey(x963Representation: Data([0x04]) + x + y)
        else {
            return nil
        }

        let expiresAt = json["expiresAt"]?.numberValue?.doubleValue.map { Date(timeIntervalSince1970: $0) }
            ?? now().addingTimeInterval(3600)
        publicKey = PublicKey(key: key, expiresAt: expiresAt)
        return key
    }

    private func fromService(_ server: String, messageHash: String) async -> (origin: String, isScam: Bool)? {
        guard
            let url = URL(string: "\(server)/attestation/\(messageHash)?v2Supported=true"),
            let response = try? await fetch(url),
            response.status == 200,
            let json = try? JSONParser.parse(response.body, maxBytes: 65536, maxDepth: 8),
            let origin = json["origin"]?.stringValue
        else {
            return nil
        }
        return (origin, json["isScam"]?.boolValue == true)
    }
}
