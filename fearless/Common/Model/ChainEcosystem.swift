enum ChainEcosystem: String, Equatable {
    case kusama
    case polkadot
    case ethereum

    var isKusama: Bool {
        switch self {
        case .kusama:
            return true
        case .polkadot, .ethereum:
            return false
        }
    }

    var isPolkadot: Bool {
        switch self {
        case .polkadot:
            return true
        case .kusama, .ethereum:
            return false
        }
    }

    var isEthereum: Bool {
        switch self {
        case .ethereum:
            return true
        case .kusama, .polkadot:
            return false
        }
    }
}
