enum AccountCreateChainType {
    case ethereum
    case substrate(choosable: Bool)

    var isEthereum: Bool {
        switch self {
        case .ethereum:
            return true
        case .substrate:
            return false
        }
    }
}
