import Foundation

struct ExportMnemonicData {
    let account: AccountItem
    let mnemonic: [String]
    let derivationPath: String?
    let networkType: Chain
}
