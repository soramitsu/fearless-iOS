import UIKit
@testable import fearless

// Bridge the hand-written test mock to the app's protocol with minimal adapters
extension WalletCommandFactoryProtocolMock: fearless.WalletCommandFactoryProtocol {
    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommand {
        // Map test mock's behavior to a simple app command
        let cmd = WalletPresentationCommand(presentingController: controller)
        return cmd
    }

    func prepareHideCommand(with action: WalletDismissAction) -> WalletPresentationCommand {
        let cmd = WalletPresentationCommand()
        return cmd
    }
}
