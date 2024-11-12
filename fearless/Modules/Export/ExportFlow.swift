import Foundation
import SSFModels

enum ExportFlow {
    case multiple(wallet: MetaAccountModel, accounts: [ChainAccountInfo])
    case single(chain: ChainModel, address: String, wallet: MetaAccountModel)

    var exportingAccounts: [ChainAccountInfo] {
        guard case let .multiple(_, accounts) = self else {
            return []
        }

        var accountsToExport: [ChainAccountInfo] = []
        accounts.forEach { chainAccountInfo in
            if chainAccountInfo.account.isChainAccount {
                accountsToExport.append(chainAccountInfo)
            } else {
                switch chainAccountInfo.account.ecosystem {
                case .substrate:
                    if accountsToExport.first(where: { $0.account.ecosystem.isSubstrate }) == nil {
                        accountsToExport.append(chainAccountInfo)
                    }
                case .ethereumBased, .ethereum:
                    if accountsToExport.first(where: { $0.account.ecosystem.isEthereum || $0.account.ecosystem.isEthereumBased }) == nil {
                        accountsToExport.append(chainAccountInfo)
                    }
                case .ton:
                    if accountsToExport.first(where: { $0.account.ecosystem.isTon }) == nil {
                        accountsToExport.append(chainAccountInfo)
                    }
                }
            }
        }

        return accountsToExport
    }

    var wallet: MetaAccountModel {
        switch self {
        case let .multiple(wallet, _):
            return wallet
        case let .single(_, _, wallet):
            return wallet
        }
    }
}
