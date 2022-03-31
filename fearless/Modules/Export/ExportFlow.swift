import Foundation

enum ExportFlow {
    case multiple(account: MetaAccountModel)
    case single(chain: ChainModel, address: String)
}
