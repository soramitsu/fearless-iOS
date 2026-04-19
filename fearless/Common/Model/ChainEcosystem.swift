enum ChainEcosystem: String, Equatable {
    case substrate
    case kusama
    case polkadot
    case ethereum
    case ethereumBased
    case ton

    var isKusama: Bool {
        switch self {
        case .kusama:
            return true
        case .substrate, .polkadot, .ethereum, .ethereumBased, .ton:
            return false
        }
    }

    var isPolkadot: Bool {
        switch self {
        case .polkadot:
            return true
        case .substrate, .kusama, .ethereum, .ethereumBased, .ton:
            return false
        }
    }

    var isEthereum: Bool {
        switch self {
        case .ethereum, .ethereumBased:
            return true
        case .substrate, .kusama, .polkadot, .ton:
            return false
        }
    }
}
