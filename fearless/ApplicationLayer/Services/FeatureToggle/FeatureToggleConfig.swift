import Foundation

struct FeatureToggleConfig: Decodable, Equatable {
    let pendulumCaseEnabled: Bool?
    let nftEnabled: Bool?
    let polkaswapMutationsEnabled: Bool
    let demeterMutationsEnabled: Bool
    let polkamarktMutationsEnabled: Bool
    let crossChainMutationsEnabled: Bool
    let assetDiscoveryShadowMode: Bool
    let signedMutationAuthorization: String?

    init(
        pendulumCaseEnabled: Bool?,
        nftEnabled: Bool?,
        polkaswapMutationsEnabled: Bool = true,
        demeterMutationsEnabled: Bool = false,
        polkamarktMutationsEnabled: Bool = false,
        crossChainMutationsEnabled: Bool = false,
        assetDiscoveryShadowMode: Bool = true,
        signedMutationAuthorization: String? = nil
    ) {
        self.pendulumCaseEnabled = pendulumCaseEnabled
        self.nftEnabled = nftEnabled
        self.polkaswapMutationsEnabled = polkaswapMutationsEnabled
        self.demeterMutationsEnabled = demeterMutationsEnabled
        self.polkamarktMutationsEnabled = polkamarktMutationsEnabled
        self.crossChainMutationsEnabled = crossChainMutationsEnabled
        self.assetDiscoveryShadowMode = assetDiscoveryShadowMode
        self.signedMutationAuthorization = signedMutationAuthorization
    }

    private enum CodingKeys: String, CodingKey {
        case pendulumCaseEnabled
        case nftEnabled
        case polkaswapMutationsEnabled
        case polkaswapMutationsEnabledLegacy = "polkaswap_mutations_enabled"
        case demeterMutationsEnabled
        case polkamarktMutationsEnabled
        case crossChainMutationsEnabled
        case assetDiscoveryShadowMode
        case signedMutationAuthorization = "mutation_authorization"
        case normalizedMutationAuthorization = "mutationAuthorization"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pendulumCaseEnabled = try container.decodeIfPresent(Bool.self, forKey: .pendulumCaseEnabled)
        nftEnabled = try container.decodeIfPresent(Bool.self, forKey: .nftEnabled)
        polkaswapMutationsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .polkaswapMutationsEnabled
        ) ?? container.decodeIfPresent(
            Bool.self,
            forKey: .polkaswapMutationsEnabledLegacy
        ) ?? true
        demeterMutationsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .demeterMutationsEnabled
        ) ?? false
        polkamarktMutationsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .polkamarktMutationsEnabled
        ) ?? false
        crossChainMutationsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .crossChainMutationsEnabled
        ) ?? false
        assetDiscoveryShadowMode = try container.decodeIfPresent(
            Bool.self,
            forKey: .assetDiscoveryShadowMode
        ) ?? true
        let rawAuthorization = try container.decodeIfPresent(String.self, forKey: .signedMutationAuthorization)
        let normalizedAuthorization = try container.decodeIfPresent(String.self, forKey: .normalizedMutationAuthorization)
        if let rawAuthorization, let normalizedAuthorization, rawAuthorization != normalizedAuthorization {
            throw DecodingError.dataCorruptedError(
                forKey: .signedMutationAuthorization,
                in: container,
                debugDescription: "Conflicting mutation authorization fields"
            )
        }
        signedMutationAuthorization = rawAuthorization ?? normalizedAuthorization
    }

    static var defaultConfig: FeatureToggleConfig {
        FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true)
    }
}

/// Process-wide, read-only-at-call-site policy for remote action kill switches.
/// Polkaswap is an existing production feature, so it remains available when
/// its newer key is absent from the legacy remote payload; an explicit false
/// still pauses mutations. New destinations continue to default fail-closed.
enum MultiChainFeaturePolicy {
    private static let lock = NSLock()
    private static var config = FeatureToggleConfig.defaultConfig
    // Missing/unprovisioned release trust denies new mutations. Public keys and
    // exact artifact/route bindings must be reviewed and bundled before enabling.
    private static var authority = try? MutationAuthorizationReleaseBinding.makeAuthority()

    static var current: FeatureToggleConfig {
        lock.lock()
        defer { lock.unlock() }
        return FeatureToggleConfig(
            pendulumCaseEnabled: config.pendulumCaseEnabled,
            nftEnabled: config.nftEnabled,
            polkaswapMutationsEnabled: config.polkaswapMutationsEnabled,
            demeterMutationsEnabled: config.demeterMutationsEnabled && authority?.isAllowed(.demeter) == true,
            polkamarktMutationsEnabled: config.polkamarktMutationsEnabled && authority?.isAllowed(.polkamarkt) == true,
            crossChainMutationsEnabled: config.crossChainMutationsEnabled && authority?.isAllowed(.xcm) == true,
            assetDiscoveryShadowMode: config.assetDiscoveryShadowMode
        )
    }

    static func authorization(
        for capability: MutationCapability,
        intentSha256: String,
        validateContext: @escaping () throws -> Void
    ) throws -> MutationOperationAuthorization {
        lock.lock()
        defer { lock.unlock() }
        guard let authority, enabled(capability, in: config) else {
            throw MutationAuthorizationError.denied
        }
        let lease = try authority.lease(for: capability, intentSha256: intentSha256)
        return try MutationOperationAuthorization(
            intentSha256: intentSha256, validateContext: validateContext
        ) { action in
            // Lock order is policy -> authority. Refresh uses the same order;
            // an unsigned disable is therefore serialized with key/sign/send.
            lock.lock()
            defer { lock.unlock() }
            guard self.authority === authority, enabled(capability, in: config) else {
                throw MutationAuthorizationError.denied
            }
            try authority.withAuthorizedContext(
                lease,
                intentSha256: intentSha256,
                validateContext: validateContext,
                action: action
            )
        }
    }

    private static func enabled(_ capability: MutationCapability, in config: FeatureToggleConfig) -> Bool {
        switch capability {
        case .xcm: return config.crossChainMutationsEnabled
        case .demeter: return config.demeterMutationsEnabled
        case .polkamarkt: return config.polkamarktMutationsEnabled
        // Existing Polkaswap is not routed through new-feature authorization.
        case .polkaswap, .polkaswapBridge: return false
        }
    }

    static func update(_ config: FeatureToggleConfig) {
        lock.lock()
        // A locked Keychain at process launch must remain denied, but may be
        // retried after unlock when a new network response arrives. An existing
        // poisoned authority is intentionally never replaced in this process.
        if authority == nil { authority = try? MutationAuthorizationReleaseBinding.makeAuthority() }
        if let token = config.signedMutationAuthorization {
            do { try authority?.acceptFreshResponse(token) }
            catch { authority?.refreshFailed() }
        } else {
            authority?.refreshFailed()
        }
        self.config = config
        lock.unlock()
    }
}
