import Foundation
import CommonWallet

struct WalletTokenViewModel: AssetSelectionViewModelProtocol {
    let header: String

    let title: String

    let subtitle: String

    let details: String

    let icon: UIImage?

    let state: SelectedAssetState

    let detailsCommand: WalletCommandProtocol?
}

extension WalletTokenViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletFearlessFormDefining {
            return definition.defineViewForFearlessTokenViewModel(self)
        } else {
            return nil
        }
    }
}
