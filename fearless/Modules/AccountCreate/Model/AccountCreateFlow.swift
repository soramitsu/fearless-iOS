enum AccountCreateFlow {
    case chain(model: UniqueChainModel)
    case wallet

    var supportsSubstrate: Bool {
        switch self {
        case .wallet:
            return true
        case let .chain(model):
            return !model.chain.isEthereumBased
        }
    }

    var supportsEthereum: Bool {
        switch self {
        case .wallet:
            return true
        case let .chain(model):
            return model.chain.isEthereumBased
        }
    }

    var supportsSelection: Bool {
        switch self {
        case .wallet:
            return true
        case .chain:
            return false
        }
    }
}
