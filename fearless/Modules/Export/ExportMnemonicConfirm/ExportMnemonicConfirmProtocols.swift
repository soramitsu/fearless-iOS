import Foundation
import IrohaCrypto
import SSFModels

protocol ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel
    ) -> AccountConfirmViewProtocol?
}
