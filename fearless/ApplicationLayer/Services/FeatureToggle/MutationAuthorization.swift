import CryptoKit
import Foundation

enum MutationCapability: String, CaseIterable, Decodable {
    case demeter, polkamarkt, polkaswap, polkaswapBridge, xcm
}

enum MutationAuthorizationError: Error, Equatable {
    case invalidToken, untrustedKey, invalidSignature, wrongRelease, expired
    case rollback, persistenceUnavailable, denied, changedIntent
}

/// These identities must come from the compiled, reviewed release manifest.
/// In particular, appVersion is the manifest's exact build ordinal, not a value
/// supplied by the configuration server or inferred from a marketing version.
struct MutationAuthorizationContext {
    let audience: String
    let appVersion: Int64
    let policySha256: String
    let routeManifestSha256: String
    let compiledCapabilities: Set<MutationCapability>
}

struct VerifiedMutationAuthorization {
    fileprivate let payload: MutationAuthorizationPayload
    let payloadSha256: String
    var revision: Int64 { payload.revisionNumber }
    var expiresAt: Int64 { payload.expiresAtNumber }
    var capabilities: Set<MutationCapability> { payload.capabilities.enabled }
}

/// FWMA1: closed ASCII JSON, canonical base64url, and pure Ed25519. Keeping the
/// canonical reconstruction independent of JSONEncoder rejects duplicate keys,
/// alternate escaping/order, unknown fields, and numeric booleans/integers.
struct MutationAuthorizationVerifier {
    let context: MutationAuthorizationContext
    let trustedKeys: [String: Data]

    func verify(_ token: String, now: Int64) throws -> VerifiedMutationAuthorization {
        guard token.utf8.count <= 8192, token.utf8.allSatisfy({ $0 < 128 }) else {
            throw MutationAuthorizationError.invalidToken
        }
        let segments = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard segments.count == 4, segments[0] == "FWMA1",
              Self.matches(segments[1], "[a-z0-9-]{1,64}") else {
            throw MutationAuthorizationError.invalidToken
        }
        guard let rawKey = trustedKeys[segments[1]], rawKey.count == 32,
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey) else {
            throw MutationAuthorizationError.untrustedKey
        }
        let bytes = try Self.decodeBase64URL(segments[2])
        let signature = try Self.decodeBase64URL(segments[3])
        guard signature.count == 64 else { throw MutationAuthorizationError.invalidSignature }
        var signedBytes = Data("FearlessWallet-MutationAuthorization-v1\n\(segments[1])\n".utf8)
        signedBytes.append(bytes)
        guard publicKey.isValidSignature(signature, for: signedBytes) else {
            throw MutationAuthorizationError.invalidSignature
        }
        guard let payload = try? JSONDecoder().decode(MutationAuthorizationPayload.self, from: bytes),
              payload.isValid, bytes == Data(payload.canonicalJSON.utf8) else {
            throw MutationAuthorizationError.invalidToken
        }
        guard context.appVersion > 0,
              payload.audience == context.audience,
              payload.minAppVersionNumber <= context.appVersion,
              payload.maxAppVersionNumber >= context.appVersion,
              payload.policySha256 == context.policySha256,
              payload.routeManifestSha256 == context.routeManifestSha256 else {
            throw MutationAuthorizationError.wrongRelease
        }
        guard now >= 0, now <= 253_402_300_799,
              payload.issuedAtNumber <= now + 60,
              now < payload.expiresAtNumber,
              payload.expiresAtNumber > payload.issuedAtNumber,
              payload.expiresAtNumber - payload.issuedAtNumber <= 900 else {
            throw MutationAuthorizationError.expired
        }
        return VerifiedMutationAuthorization(payload: payload, payloadSha256: Self.sha256(bytes))
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: "\\A(?:\(pattern))\\z", options: .regularExpression) != nil
    }

    private static func decodeBase64URL(_ value: String) throws -> Data {
        guard matches(value, "[A-Za-z0-9_-]+") else {
            throw MutationAuthorizationError.invalidToken
        }
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let decoded = Data(base64Encoded: base64),
              decoded.base64EncodedString().replacingOccurrences(of: "+", with: "-")
              .replacingOccurrences(of: "/", with: "_")
              .replacingOccurrences(of: "=", with: "") == value else {
            throw MutationAuthorizationError.invalidToken
        }
        return decoded
    }
}

private struct MutationAuthorizationPayload: Decodable {
    struct Capabilities: Decodable {
        let demeter: Bool
        let polkamarkt: Bool
        let polkaswap: Bool
        let polkaswapBridge: Bool
        let xcm: Bool

        var enabled: Set<MutationCapability> {
            var result: Set<MutationCapability> = []
            if demeter { result.insert(.demeter) }
            if polkamarkt { result.insert(.polkamarkt) }
            if polkaswap { result.insert(.polkaswap) }
            if polkaswapBridge { result.insert(.polkaswapBridge) }
            if xcm { result.insert(.xcm) }
            return result
        }

        var canonicalJSON: String {
            "{\"demeter\":\(demeter),\"polkamarkt\":\(polkamarkt)," +
                "\"polkaswap\":\(polkaswap),\"polkaswapBridge\":\(polkaswapBridge),\"xcm\":\(xcm)}"
        }
    }

    let schema: String
    let audience: String
    let environment: String
    let minAppVersion: String
    let maxAppVersion: String
    let policySha256: String
    let routeManifestSha256: String
    let revision: String
    let issuedAt: String
    let expiresAt: String
    let capabilities: Capabilities

    var minAppVersionNumber: Int64 { Int64(minAppVersion) ?? -1 }
    var maxAppVersionNumber: Int64 { Int64(maxAppVersion) ?? -1 }
    var revisionNumber: Int64 { Int64(revision) ?? -1 }
    var issuedAtNumber: Int64 { Int64(issuedAt) ?? -1 }
    var expiresAtNumber: Int64 { Int64(expiresAt) ?? -1 }

    var isValid: Bool {
        schema == "1" && environment == "production" &&
            MutationAuthorizationVerifier.matches(audience, "[A-Za-z0-9.-]{1,128}") &&
            MutationAuthorizationVerifier.matches(policySha256, "[0-9a-f]{64}") &&
            MutationAuthorizationVerifier.matches(routeManifestSha256, "[0-9a-f]{64}") &&
            [minAppVersion, maxAppVersion, revision, issuedAt, expiresAt].allSatisfy {
                MutationAuthorizationVerifier.matches($0, "0|[1-9][0-9]{0,18}") && Int64($0) != nil
            } && minAppVersionNumber > 0 && maxAppVersionNumber >= minAppVersionNumber &&
            revisionNumber > 0 && issuedAtNumber <= 253_402_300_799 && expiresAtNumber <= 253_402_300_799
    }

    var canonicalJSON: String {
        "{\"schema\":\"\(schema)\",\"audience\":\"\(audience)\",\"environment\":\"\(environment)\"," +
            "\"minAppVersion\":\"\(minAppVersion)\",\"maxAppVersion\":\"\(maxAppVersion)\"," +
            "\"policySha256\":\"\(policySha256)\",\"routeManifestSha256\":\"\(routeManifestSha256)\"," +
            "\"revision\":\"\(revision)\",\"issuedAt\":\"\(issuedAt)\",\"expiresAt\":\"\(expiresAt)\"," +
            "\"capabilities\":\(capabilities.canonicalJSON)}"
    }
}
