import Foundation
import IrohaCrypto

protocol ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel
    ) -> AccountConfirmViewProtocol?
}
