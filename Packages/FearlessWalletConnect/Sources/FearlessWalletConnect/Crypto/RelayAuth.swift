import CryptoKit
import Foundation

/// The relay's sign-in: an EdDSA JWT for the relay URL, issued by the client's Ed25519 identity as a did:key.
enum RelayAuth {
    static let defaultLifetime: Int64 = 86400

    /// The multicodec prefix of an Ed25519 public key (0xed 0x01).
    private static let ed25519Multicodec = Data([0xED, 0x01])

    static func clientId(publicKey: Data) -> String {
        "did:key:z" + Base58.encode(ed25519Multicodec + publicKey)
    }

    static func clientId(seed: Data) throws -> String {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        return clientId(publicKey: key.publicKey.rawRepresentation)
    }

    /// The token the relay accepts in the `auth` query parameter. The claims are written in the order
    /// WalletConnect's relay-auth writes them: iss, sub, aud, iat, exp.
    static func token(
        seed: Data,
        audience: String,
        subject: String,
        issuedAt: Int64,
        lifetime: Int64 = defaultLifetime
    ) throws -> String {
        guard seed.count == 32 else {
            throw WalletConnectCryptoError.invalidKey
        }
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let header = #"{"alg":"EdDSA","typ":"JWT"}"#
        let issuer = clientId(publicKey: key.publicKey.rawRepresentation)
        let payload = "{"
            + "\"iss\":\(JSONSerializer.quoted(issuer)),"
            + "\"sub\":\(JSONSerializer.quoted(subject)),"
            + "\"aud\":\(JSONSerializer.quoted(audience)),"
            + "\"iat\":\(issuedAt),"
            + "\"exp\":\(issuedAt + lifetime)"
            + "}"
        let signingInput = Base64.encodeURL(Data(header.utf8)) + "." + Base64.encodeURL(Data(payload.utf8))
        let signature = try key.signature(for: Data(signingInput.utf8))
        return signingInput + "." + Base64.encodeURL(signature)
    }

    /// A JWT's claims, unverified.
    static func payload(ofToken token: String) -> JSONValue? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let data = Base64.decodeURL(String(parts[1])) else {
            return nil
        }
        return try? JSONParser.parse(data, maxBytes: 16384, maxDepth: 8)
    }

    static func header(ofToken token: String) -> JSONValue? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let data = Base64.decodeURL(String(parts[0])) else {
            return nil
        }
        return try? JSONParser.parse(data, maxBytes: 4096, maxDepth: 4)
    }
}
