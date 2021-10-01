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
        view?.contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 12.0, right: 0.0)
        return view
    }

    func createAmountView() -> BaseAmountInputView? {
        let amountView = WalletInputAmountView()
        amountView.localizationManager = localizationManager
        return amountView
    }

    func createFeeView() -> BaseFeeView? {
        UIFactory().createNetworkFeeView()
    }
}
