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
        R.nib.walletCompoundDetailsView(owner: nil)
    }

    func createAmountView() -> BaseAmountInputView? {
        let amountView = WalletInputAmountView()
        amountView.localizationManager = localizationManager
        return amountView
    }

    func createFeeView() -> BaseFeeView? {
        nil
//        return NetworkFeeView(): BaseFeeView
        // TODO: Create custom view
    }
}
