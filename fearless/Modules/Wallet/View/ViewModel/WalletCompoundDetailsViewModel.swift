import Foundation
import CommonWallet

struct WalletCompoundDetailsViewModel: WalletFormViewBindingProtocol {
    let title: String
    let details: String
    let mainIcon: UIImage?
    let actionIcon: UIImage?
    let command: WalletCommandProtocol

    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletFearlessFormDefining {
            return definition.defineViewForCompoundDetails(self)
        } else {
            return nil
        }
    }
}
