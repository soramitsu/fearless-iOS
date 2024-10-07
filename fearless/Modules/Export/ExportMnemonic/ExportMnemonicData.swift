import Foundation
import IrohaCrypto
import SSFUtils
import SSFModels

struct ExportMnemonicData {
    let mnemonic: [String]
    let derivationPath: String?
    let cryptoType: CryptoType?
    let chain: ChainModel
}
