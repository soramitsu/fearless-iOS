import Foundation
import IrohaCrypto
import SSFModels
import SSFUtils

struct ExportMnemonicData {
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let cryptoType: CryptoType?
    let chain: ChainModel
    let backupProof: VerifiedMnemonicBackup?

    init(
        mnemonic: IRMnemonicProtocol,
        derivationPath: String?,
        cryptoType: CryptoType?,
        chain: ChainModel,
        backupProof: VerifiedMnemonicBackup? = nil
    ) {
        self.mnemonic = mnemonic
        self.derivationPath = derivationPath
        self.cryptoType = cryptoType
        self.chain = chain
        self.backupProof = backupProof
    }
}

struct ExportMnemonicNotShown {
    let chain: ChainModel
    let error: Error
}
