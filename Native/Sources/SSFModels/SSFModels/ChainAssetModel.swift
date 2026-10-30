public enum PurchaseProvider: String, Codable, Hashable {
    case moonpay
    case ramp
}

public enum RawStakingType: String, Codable {
    case relayChain = "relaychain"
    case paraChain = "parachain"

    public var isRelaychain: Bool {
        switch self {
        case .relayChain:
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
    case sora
    case ternoa

    public var isRelaychain: Bool {
        switch self {
        case .relaychain, .sora, .ternoa:
            return true
        }
    }

    /// Parachain (collator) staking served only Moonbeam, Moonriver and Moonbase Alpha and is no longer offered:
    /// a stored or downloaded `parachain` asset still decodes but has no staking type.
    public init?(rawStakingType: RawStakingType) {
        switch rawStakingType {
        case .relayChain:
            self = .relaychain
        case .paraChain:
            return nil
        }
    }

    public init?(chainAsset: ChainAsset) {
        switch chainAsset.chain.knownChainEquivalent {
        case .soraMain, .soraTest:
            self = .sora
        case .ternoa:
            self = .ternoa
        default:
            guard
                let rawStakingType = chainAsset.rawStakingType,
                let stakingType = StakingType(rawStakingType: rawStakingType)
            else {
                return nil
            }

            self = stakingType
        }
    }
}
