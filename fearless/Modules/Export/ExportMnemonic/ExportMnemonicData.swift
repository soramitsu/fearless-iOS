import Foundation
import IrohaCrypto
import FearlessUtils

struct ExportMnemonicData {
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let cryptoType: CryptoType
}
