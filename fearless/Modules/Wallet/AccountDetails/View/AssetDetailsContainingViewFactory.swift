import UIKit
import CommonWallet

struct AssetDetailsContainingViewFactory: AccountDetailsContainingViewFactoryProtocol {
    func createView() -> BaseAccountDetailsContainingView {
        R.nib.assetDetailsView(owner: nil)!
    }
}
