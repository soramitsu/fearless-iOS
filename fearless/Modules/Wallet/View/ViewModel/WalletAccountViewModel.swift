import Foundation
import CommonWallet

struct WalletAccountViewModel: MultilineTitleIconViewModelProtocol {
    let text: String
    let icon: UIImage?
    let copyCommand: WalletCommandProtocol
}

extension WalletAccountViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletFearlessFormDefining {
            return definition.defineViewForFearlessAccountViewModel(self)
        } else {
            return nil
        }
    }
}
