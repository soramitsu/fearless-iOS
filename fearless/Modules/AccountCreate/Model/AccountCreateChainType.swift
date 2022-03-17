enum AccountCreateChainType {
    case ethereum
    case substrate(choosable: Bool)
    case both
}

extension AccountCreateChainType {
    var includeSubstrate: Bool {
        switch self {
        case .substrate, .both:
            return true
        case .ethereum:
            return false
        }
    }

    var includeEthereum: Bool {
        switch self {
        case .ethereum, .both:
            return true
        case .substrate:
            return false
        }
    }
}
