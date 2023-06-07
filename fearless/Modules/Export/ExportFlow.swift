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
            if !chainAccountInfo.account.isChainAccount {
                if chainAccountInfo.account.isEthereumBased, accountsToExport.first(where: { $0.account.isEthereumBased && !$0.account.isChainAccount }) == nil {
                    accountsToExport.append(chainAccountInfo)
                }

                if !chainAccountInfo.account.isEthereumBased, accountsToExport.first(where: { !$0.account.isEthereumBased && !$0.account.isChainAccount }) == nil {
                    accountsToExport.append(chainAccountInfo)
                }
            } else {
                accountsToExport.append(chainAccountInfo)
            }
        }

        return accountsToExport
    }
}
