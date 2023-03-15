enum ChainEcosystem: String, Equatable {
    case kusama
    case polkadot

    var isKusama: Bool {
        switch self {
        case .kusama:
            return true
        case .polkadot:
            return false
        }
    }

    var isPolkadot: Bool {
        switch self {
        case .polkadot:
            return true
        case .kusama:
            return false
        }
    }
}
