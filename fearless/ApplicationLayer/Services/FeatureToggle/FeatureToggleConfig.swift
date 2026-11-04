import Foundation

/// Remote keys for fund-moving features this build ships enabled. The remote
/// feature_toggle may only veto them: an explicit `false` pauses the feature and
/// is remembered, only a later explicit `true` lifts the veto, and an absent key
/// or a failed fetch changes nothing (critique C3, release invariant 7).
enum RemoteKillSwitch: String, CaseIterable {
    case polkaswapMutations = "polkaswap_mutations"
    case bitcoinSend = "bitcoin_send"
    case solanaSend = "solana_send"

    var storageKey: String {
        "feature.kill_switch.\(rawValue)"
    }
}

struct FeatureToggleConfig: Decodable, Equatable {
    let pendulumCaseEnabled: Bool?
    let nftEnabled: Bool?
    let polkaswapMutationsEnabled: Bool
    let demeterMutationsEnabled: Bool
    let polkamarktMutationsEnabled: Bool
    let crossChainMutationsEnabled: Bool
    let bitcoinSendEnabled: Bool
    let solanaSendEnabled: Bool
    let assetDiscoveryShadowMode: Bool
    let signedMutationAuthorization: String?
    /// Kill-switch values the payload stated explicitly. Only these record or
    /// lift a remembered veto; a key the payload omits leaves it untouched.
    let explicitKillSwitches: [RemoteKillSwitch: Bool]

    init(
        pendulumCaseEnabled: Bool?,
        nftEnabled: Bool?,
        polkaswapMutationsEnabled: Bool = true,
        demeterMutationsEnabled: Bool = false,
        polkamarktMutationsEnabled: Bool = false,
        crossChainMutationsEnabled: Bool = false,
        bitcoinSendEnabled: Bool = true,
        solanaSendEnabled: Bool = true,
        assetDiscoveryShadowMode: Bool = true,
        signedMutationAuthorization: String? = nil,
        explicitKillSwitches: [RemoteKillSwitch: Bool] = [:]
    ) {
        self.pendulumCaseEnabled = pendulumCaseEnabled
        self.nftEnabled = nftEnabled
        self.polkaswapMutationsEnabled = polkaswapMutationsEnabled
        self.demeterMutationsEnabled = demeterMutationsEnabled
        self.polkamarktMutationsEnabled = polkamarktMutationsEnabled
        self.crossChainMutationsEnabled = crossChainMutationsEnabled
        self.bitcoinSendEnabled = bitcoinSendEnabled
        self.solanaSendEnabled = solanaSendEnabled
        self.assetDiscoveryShadowMode = assetDiscoveryShadowMode
        self.signedMutationAuthorization = signedMutationAuthorization
        self.explicitKillSwitches = explicitKillSwitches
    }

    private enum CodingKeys: String, CodingKey {
        case pendulumCaseEnabled
        case nftEnabled
        case polkaswapMutationsEnabled
        case polkaswapMutationsEnabledLegacy = "polkaswap_mutations_enabled"
        case demeterMutationsEnabled
        case polkamarktMutationsEnabled
        case crossChainMutationsEnabled
        case bitcoinSendEnabled
        case bitcoinSendEnabledLegacy = "bitcoin_send_enabled"
        case solanaSendEnabled
        case solanaSendEnabledLegacy = "solana_send_enabled"
        case assetDiscoveryShadowMode
        case signedMutationAuthorization = "mutation_authorization"
        case normalizedMutationAuthorization = "mutationAuthorization"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pendulumCaseEnabled = try container.decodeIfPresent(Bool.self, forKey: .pendulumCaseEnabled)
        nftEnabled = try container.decodeIfPresent(Bool.self, forKey: .nftEnabled)
        let remotePolkaswap = try container.decodeIfPresent(
            Bool.self,
            forKey: .polkaswapMutationsEnabled
        ) ?? container.decodeIfPresent(
            Bool.self,
            forKey: .polkaswapMutationsEnabledLegacy
        )
        let remoteBitcoinSend = try container.decodeIfPresent(
            Bool.self,
            forKey: .bitcoinSendEnabled
        ) ?? container.decodeIfPresent(
            Bool.self,
            forKey: .bitcoinSendEnabledLegacy
        )
        let remoteSolanaSend = try container.decodeIfPresent(
            Bool.self,
            forKey: .solanaSendEnabled
        ) ?? container.decodeIfPresent(
            Bool.self,
            forKey: .solanaSendEnabledLegacy
        )
        polkaswapMutationsEnabled = remotePolkaswap ?? true
        bitcoinSendEnabled = remoteBitcoinSend ?? true
        solanaSendEnabled = remoteSolanaSend ?? true
        let remoteKillSwitches: [RemoteKillSwitch: Bool?] = [
            .polkaswapMutations: remotePolkaswap,
            .bitcoinSend: remoteBitcoinSend,
            .solanaSend: remoteSolanaSend
        ]
        explicitKillSwitches = remoteKillSwitches.compactMapValues { $0 }
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

    /// Used before the first fetch and whenever a fetch fails or cannot be decoded.
    /// The live payload switches NFTs off, so the fallback keeps NFT send off too;
    /// otherwise every offline launch would bring back a feature the remote vetoed.
    static var defaultConfig: FeatureToggleConfig {
        FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: false)
    }
}

/// Importing a wallet from a recovery phrase encoded in a QR code ("preinstalled
/// wallet") was an event flow that only a remote `pendulum_case_enabled: true` could
/// switch on. Remote config may only veto features (release invariant 7), so this
/// build compiles the flow off and ignores the remote value.
enum PreinstalledWalletImportPolicy {
    static let isCompiledIn = false

    static func isAvailable(remote config: FeatureToggleConfig, isCompiledIn: Bool = isCompiledIn) -> Bool {
        isCompiledIn && config.pendulumCaseEnabled == true
    }
}

/// Remembers remote vetoes across launches, offline starts and failed fetches.
/// A veto is written only from a successfully fetched payload that states the key
/// as `false`, and is cleared only by a later payload that states it as `true`.
/// It stores presentation policy flags only, never wallet or key material.
final class RemoteKillSwitchStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var vetoes: Set<RemoteKillSwitch> {
        Set(RemoteKillSwitch.allCases.filter {
            defaults.object(forKey: $0.storageKey) as? Bool == false
        })
    }

    func record(_ explicitValues: [RemoteKillSwitch: Bool]) {
        for (killSwitch, isEnabled) in explicitValues {
            if isEnabled {
                defaults.removeObject(forKey: killSwitch.storageKey)
            } else {
                defaults.set(false, forKey: killSwitch.storageKey)
            }
        }
    }
}

/// Process-wide, read-only-at-call-site policy for remote action kill switches.
/// Polkaswap, Bitcoin send and Solana send ship enabled, so they stay available
/// when their keys are absent from the legacy remote payload; an explicit false
/// pauses them and is remembered until an explicit true (`RemoteKillSwitchStore`).
/// New destinations continue to default fail-closed.
enum MultiChainFeaturePolicy {
    private static let lock = NSLock()
    private static var config = FeatureToggleConfig.defaultConfig
    private static let killSwitchStore = RemoteKillSwitchStore()
    private static var vetoes = killSwitchStore.vetoes
    // Missing/unprovisioned release trust denies new mutations. Public keys and
    // exact artifact/route bindings must be reviewed and bundled before enabling.
    private static var authority = try? MutationAuthorizationReleaseBinding.makeAuthority()

    static var current: FeatureToggleConfig {
        lock.lock()
        defer { lock.unlock() }
        return FeatureToggleConfig(
            pendulumCaseEnabled: config.pendulumCaseEnabled,
            nftEnabled: config.nftEnabled,
            polkaswapMutationsEnabled: config.polkaswapMutationsEnabled && !vetoes.contains(.polkaswapMutations),
            demeterMutationsEnabled: config.demeterMutationsEnabled && authority?.isAllowed(.demeter) == true,
            polkamarktMutationsEnabled: config.polkamarktMutationsEnabled && authority?.isAllowed(.polkamarkt) == true,
            crossChainMutationsEnabled: config.crossChainMutationsEnabled && authority?.isAllowed(.xcm) == true,
            bitcoinSendEnabled: config.bitcoinSendEnabled && !vetoes.contains(.bitcoinSend),
            solanaSendEnabled: config.solanaSendEnabled && !vetoes.contains(.solanaSend),
            assetDiscoveryShadowMode: config.assetDiscoveryShadowMode
        )
    }

    /// `expectedCall`, when given, is the exact call the intent was confirmed for; the signed extrinsic must carry it.
    static func authorization(
        for capability: MutationCapability,
        intentSha256: String,
        expectedCall: Data? = nil,
        validateContext: @escaping () throws -> Void
    ) throws -> MutationOperationAuthorization {
        lock.lock()
        defer { lock.unlock() }
        guard let authority, enabled(capability, in: config) else {
            throw MutationAuthorizationError.denied
        }
        let lease = try authority.lease(for: capability, intentSha256: intentSha256)
        return try MutationOperationAuthorization(
            intentSha256: intentSha256, expectedCall: expectedCall, validateContext: validateContext
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
        // The failed-fetch default carries no explicit kill switches, so it can
        // neither record nor lift a veto.
        killSwitchStore.record(config.explicitKillSwitches)
        vetoes = killSwitchStore.vetoes
        self.config = config
        lock.unlock()
    }
}
