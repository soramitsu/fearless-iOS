public enum PurchaseProvider: String, Codable, Hashable {
    case moonpay
    case ramp
}

public enum RawStakingType: String, Codable {
    case relayChain = "relaychain"
    case paraChain = "parachain"
    /// Relay-chain-type staking that moved to an Asset Hub. A build that does not know this value decodes the
    /// asset without staking, so it never runs relay staking code against a hub.
    case assetHub

    public var isRelaychain: Bool {
        switch self {
        case .relayChain, .assetHub:
            return true
        default:
            return false
        }
    }

    public var isParachain: Bool {
        switch self {
        case .paraChain:
            return true
        default:
            return false
        }
    }
}

public enum StakingType {
    case relaychain
    case parachain
    case sora
    case ternoa

    public var isRelaychain: Bool {
        switch self {
        case .relaychain, .sora, .ternoa:
            return true
        default:
            return false
        }
    }

    public var isParachain: Bool {
        switch self {
        case .parachain:
            return true
        default:
            return false
        }
    }

    public init(rawStakingType: RawStakingType) {
        switch rawStakingType {
        case .relayChain, .assetHub:
            self = .relaychain
        case .paraChain:
            self = .parachain
        }
    }

    public init?(chainAsset: ChainAsset) {
        switch chainAsset.chain.knownChainEquivalent {
        case .soraMain, .soraTest:
            self = .sora
        case .ternoa:
            self = .ternoa
        default:
            guard let stakingType = chainAsset.rawStakingType else {
                return nil
            }

            self = StakingType(rawStakingType: stakingType)
        }
    }
}
