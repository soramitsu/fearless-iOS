import Foundation
import CommonWallet

struct TransferConfirmAccessoryViewFactory: CommonWallet.AccessoryViewFactoryProtocol {
    static func createAccessoryView(
        from _: WalletAccessoryViewType,
        style _: WalletAccessoryStyleProtocol?,
        target: Any?,
        completionSelector: Selector?
    ) -> CommonWallet.AccessoryViewProtocol {
        let view = UIFactory().createNetworkFeeConfirmView()

        if let target = target, let selector = completionSelector {
            view.actionButton.addTarget(target, action: selector, for: .touchUpInside)
        }

        return view
    }
}
