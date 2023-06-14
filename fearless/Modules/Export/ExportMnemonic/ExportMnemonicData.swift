import Foundation
import IrohaCrypto
import SSFUtils
import SSFModels

struct ExportMnemonicData {
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let cryptoType: CryptoType?
    let chain: ChainModel
}
