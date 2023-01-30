import SoraFoundation
import CommonWallet

protocol RichAmountDisplayViewModelProtocol: WalletFormViewBindingProtocol,
    AssetBalanceViewModelProtocol {
    var title: String { get }
    var amount: String { get }
}

struct RichAmountDisplayViewModel: RichAmountDisplayViewModelProtocol {
    var iconViewModel: ImageViewModelProtocol?

    let title: String
    let amount: String
    let icon: UIImage?
    let symbol: String
    let balance: String?
    let fiatBalance: String?
    let price: String?

    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletFearlessFormDefining {
            return definition.defineViewForAmountDisplay(self)
        } else {
            return nil
        }
    }
}
