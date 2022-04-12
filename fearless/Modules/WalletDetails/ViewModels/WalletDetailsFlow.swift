import Foundation

enum WalletDetailsFlow {
    case normal(wallet: MetaAccountModel)
    case export(wallet: MetaAccountModel, accounts: [ChainAccountInfo])

    var actionsAvailable: Bool {
        if case .normal = self {
            return true
        }

        return false
    }

    var wallet: MetaAccountModel {
        switch self {
        case let .normal(wallet):
            return wallet
        case let .export(wallet, _):
            return wallet
        }
    }
}
