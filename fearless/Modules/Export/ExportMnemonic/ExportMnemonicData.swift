import Foundation
import IrohaCrypto

struct ExportMnemonicData {
    let account: AccountItem
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let networkType: Chain
}
