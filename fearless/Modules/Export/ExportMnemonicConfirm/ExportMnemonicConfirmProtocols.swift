import Foundation
import IrohaCrypto
import SSFModels

protocol ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(
        _ mnemonic: [String],
        wallet: MetaAccountModel
    ) -> AccountConfirmViewProtocol?
}
