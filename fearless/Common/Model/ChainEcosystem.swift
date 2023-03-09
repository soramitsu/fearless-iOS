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
}
