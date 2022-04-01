import Foundation

enum ExportFlow {
    case multiple(wallet: MetaAccountModel, accounts: [ChainAccountResponse])
    case single(chain: ChainModel, address: String)
}
