import Foundation

struct FeatureToggleConfig: Decodable, Equatable {
    let pendulumCaseEnabled: Bool?
    let nftEnabled: Bool?
    let polkaswapMutationsEnabled: Bool
    let demeterMutationsEnabled: Bool
    let polkamarktMutationsEnabled: Bool
    let crossChainMutationsEnabled: Bool
    let assetDiscoveryShadowMode: Bool

    init(
        pendulumCaseEnabled: Bool?,
        nftEnabled: Bool?,
        polkaswapMutationsEnabled: Bool = true,
        demeterMutationsEnabled: Bool = false,
        polkamarktMutationsEnabled: Bool = false,
        crossChainMutationsEnabled: Bool = false,
        assetDiscoveryShadowMode: Bool = true
    ) {
        self.pendulumCaseEnabled = pendulumCaseEnabled
        self.nftEnabled = nftEnabled
        self.polkaswapMutationsEnabled = polkaswapMutationsEnabled
        self.demeterMutationsEnabled = demeterMutationsEnabled
        self.polkamarktMutationsEnabled = polkamarktMutationsEnabled
        self.crossChainMutationsEnabled = crossChainMutationsEnabled
        self.assetDiscoveryShadowMode = assetDiscoveryShadowMode
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

    static var current: FeatureToggleConfig {
        lock.lock()
        defer { lock.unlock() }
        return config
    }

    static func update(_ config: FeatureToggleConfig) {
        lock.lock()
        self.config = config
        lock.unlock()
    }
}
