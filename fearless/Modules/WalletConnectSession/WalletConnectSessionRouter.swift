import Foundation
import FearlessUI

final class WalletConnectSessionRouter: WalletConnectSessionRouterInput {
    var onGoToConfirmation: ((WalletConnectConfirmationInputData) -> Void)?

    init(onGoToConfirmation: ((WalletConnectConfirmationInputData) -> Void)?) {
        self.onGoToConfirmation = onGoToConfirmation
    }

    func showConfirmation(inputData: WalletConnectConfirmationInputData) {
        onGoToConfirmation?(inputData)
    }
}
