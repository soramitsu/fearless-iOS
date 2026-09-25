import Foundation

/// Reviewed build resources are the only trust source. The release-manifest
/// audit must also bind these exact bytes and compiled route inventories to the
/// shipping source. Downloaded configuration cannot change this binding.
enum MutationAuthorizationReleaseBinding {
    // This generated inventory must cover executable and discovery-only routes,
    // canonical asset identities, precision and call descriptors. Release CI
    // must compare it with the compiled registries; an arbitrary bundled file
    // is not a substitute. Provisioning that generator/evidence remains a gate.
    private static let requiredRouteFiles: Set<String> = ["mutation_route_inventory.json"]
    private struct Trust: Decodable {
        let schema: String
        let policySha256: String
        let routeManifestSha256: String
        let keys: [String: String]
    }

    private struct Policy: Decodable {
        let schema: String
        let audience: String
        let environment: String
        let appVersion: String
        let bundleVersion: String
        let capabilities: [String: Bool]
    }

    private struct Routes: Decodable {
        let schema: String
        let files: [String: String]
    }

    static func verifier(
        policyData: Data,
        trustData: Data,
        routeManifestData: Data,
        applicationId: String,
        bundleVersion: String,
        routeFile: (String) throws -> Data
    ) throws -> MutationAuthorizationVerifier {
        let trust: Trust = try decode(trustData, fields: ["schema", "policySha256", "routeManifestSha256", "keys"])
        let policy: Policy = try decode(policyData, fields: ["schema", "audience", "environment", "appVersion", "bundleVersion", "capabilities"])
        let routes: Routes = try decode(routeManifestData, fields: ["schema", "files"])
        guard trust.schema == "1", policy.schema == "1", routes.schema == "1",
              policy.environment == "production", policy.audience == applicationId,
              policy.bundleVersion == bundleVersion, !bundleVersion.isEmpty,
              MutationAuthorizationVerifier.matches(applicationId, "[A-Za-z0-9.-]{1,128}"),
              MutationAuthorizationVerifier.matches(policy.appVersion, "[1-9][0-9]{0,18}"),
              let version = Int64(policy.appVersion),
              trust.policySha256 == MutationAuthorizationVerifier.sha256(policyData),
              trust.routeManifestSha256 == MutationAuthorizationVerifier.sha256(routeManifestData),
              Set(policy.capabilities.keys) == Set(MutationCapability.allCases.map(\.rawValue)),
              !trust.keys.isEmpty, trust.keys.count <= 16,
              Set(routes.files.keys) == requiredRouteFiles else {
            throw MutationAuthorizationError.wrongRelease
        }
        var keys: [String: Data] = [:]
        for (id, encoded) in trust.keys {
            guard MutationAuthorizationVerifier.matches(id, "[a-z0-9-]{1,64}"),
                  MutationAuthorizationVerifier.matches(encoded, "[0-9a-f]{64}") else {
                throw MutationAuthorizationError.untrustedKey
            }
            keys[id] = try Data(stride(from: 0, to: 64, by: 2).map {
                let start = encoded.index(encoded.startIndex, offsetBy: $0)
                guard let byte = UInt8(encoded[start ..< encoded.index(start, offsetBy: 2)], radix: 16) else {
                    throw MutationAuthorizationError.untrustedKey
                }
                return byte
            })
        }
        for (name, expected) in routes.files {
            guard MutationAuthorizationVerifier.matches(name, "[A-Za-z0-9_-]+\\.[A-Za-z0-9]+"),
                  MutationAuthorizationVerifier.matches(expected, "[0-9a-f]{64}") else {
                throw MutationAuthorizationError.wrongRelease
            }
            let bytes = try routeFile(name)
            guard bytes.count <= 4 * 1024 * 1024,
                  MutationAuthorizationVerifier.sha256(bytes) == expected else {
                throw MutationAuthorizationError.wrongRelease
            }
        }
        return MutationAuthorizationVerifier(
            context: MutationAuthorizationContext(
                audience: applicationId, appVersion: version,
                policySha256: trust.policySha256, routeManifestSha256: trust.routeManifestSha256,
                compiledCapabilities: Set(MutationCapability.allCases.filter { policy.capabilities[$0.rawValue] == true })
            ), trustedKeys: keys
        )
    }

    static func makeAuthority(bundle: Bundle = .main) throws -> MutationAuthorizationAuthority {
        guard let applicationId = bundle.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            throw MutationAuthorizationError.wrongRelease
        }
        func resource(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: nil) else {
                throw MutationAuthorizationError.wrongRelease
            }
            return try Data(contentsOf: url)
        }
        let verifier = try verifier(
            policyData: resource("mutation_authorization_policy.json"),
            trustData: resource("mutation_authorization_trust.json"),
            routeManifestData: resource("mutation_route_manifest.json"),
            applicationId: applicationId, bundleVersion: version, routeFile: resource
        )
        return try MutationAuthorizationAuthority(
            verifier: verifier,
            store: MutationAuthorizationKeychainStore(audience: applicationId),
            clock: MutationAuthorizationClock.system
        )
    }

    private static func decode<T: Decodable>(_ data: Data, fields: Set<String>) throws -> T {
        guard data.count <= 64 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == fields,
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            throw MutationAuthorizationError.wrongRelease
        }
        return value
    }
}
