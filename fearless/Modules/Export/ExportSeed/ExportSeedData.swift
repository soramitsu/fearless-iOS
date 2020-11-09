import Foundation

struct ExportSeedData {
    let account: AccountItem
    let seed: Data
    let derivationPath: String?
    let networkType: Chain
}
