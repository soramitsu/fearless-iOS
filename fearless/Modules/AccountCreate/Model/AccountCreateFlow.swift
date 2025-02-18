import SSFModels

enum AccountCreateFlow {
    case chain(model: UniqueChainModel)
    case wallet
    case backup
    case ethereum(wallet: MetaAccountModel, chains: [ChainModel])

    var supportsSubstrate: Bool {
        switch self {
        case .wallet, .backup:
            return true
        case let .chain(model):
            return !model.chain.isEthereumBased
        case .ethereum:
            return false
        }
    }

    var supportsEthereum: Bool {
        switch self {
        case .wallet, .backup, .ethereum:
            return true
        case let .chain(model):
            return model.chain.isEthereumBased
        }
    }

    var supportsSelection: Bool {
        switch self {
        case .wallet, .backup:
            return true
        case .chain, .ethereum:
            return false
        }
    }

    var predefinedUsername: String {
        switch self {
        case .wallet, .backup:
            return ""
        case let .chain(model):
            return model.meta.name
        case let .ethereum(wallet, _):
            return wallet.name
        }
    }
}
