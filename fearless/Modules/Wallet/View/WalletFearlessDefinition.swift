import Foundation
import CommonWallet
import SoraFoundation

final class WalletFearlessDefinition: WalletFearlessFormDefining {
    let binder: WalletFormViewModelBinderProtocol
    let itemViewFactory: WalletFormItemViewFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        binder: WalletFormViewModelBinderProtocol,
        itemViewFactory: WalletFormItemViewFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.binder = binder
        self.itemViewFactory = itemViewFactory
        self.localizationManager = localizationManager
    }

    func defineViewForFearlessTokenViewModel(_: WalletTokenViewModel) -> WalletFormItemView? {
        nil
    }

    func defineViewForCompoundDetails(_ viewModel: WalletCompoundDetailsViewModel) -> WalletFormItemView? {
        let detailsView = R.nib.walletCompoundDetailsView(owner: nil)!
        detailsView.bind(viewModel: viewModel)
        return detailsView
    }

    func defineViewForAmountDisplay(
        _ viewModel: RichAmountDisplayViewModel) -> WalletFormItemView? {
        let amountDisplayView = WalletDisplayAmountView()
        amountDisplayView.bind(viewModel: viewModel)
        amountDisplayView.localizationManager = localizationManager
        return amountDisplayView
    }
}
