import Foundation
import IrohaCrypto

protocol ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonics(
        _ mnemonics: [IRMnemonicProtocol],
        wallet: MetaAccountModel
    ) -> AccountConfirmViewProtocol?
}
