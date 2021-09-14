import Foundation
import CommonWallet
import SoraFoundation

final class TransferDefinitionFactory: OperationDefinitionViewFactoryOverriding {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func createAssetView() -> BaseSelectedAssetView? {
        DummySelectedAssetView()
    }

    func createReceiverView() -> BaseReceiverView? {
        let view = R.nib.walletCompoundDetailsView(owner: nil)
        return view
    }

    func createAmountView() -> BaseAmountInputView? {
        let amountView = WalletInputAmountView()
        amountView.localizationManager = localizationManager
        return amountView
    }
}
