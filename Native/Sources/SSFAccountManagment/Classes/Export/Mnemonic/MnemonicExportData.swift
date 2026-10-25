import Foundation
import IrohaCrypto
import SSFModels

struct MnemonicExportData {
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let cryptoType: CryptoType?
    let chain: ChainModel
}
