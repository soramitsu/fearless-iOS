import Foundation
import CommonWallet

final class TransferDefinitionFactory: OperationDefinitionViewFactoryOverriding {
    func createAssetView() -> BaseSelectedAssetView? {
        WalletTransferTokenView()
    }

    func createReceiverView() -> BaseReceiverView? {
        WalletTransferReceiverView()
    }

    func createAmountView() -> BaseAmountInputView? {
        WalletInputAmountView()
    }

}
