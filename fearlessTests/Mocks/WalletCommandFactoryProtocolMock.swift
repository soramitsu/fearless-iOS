import Foundation
import UIKit
@testable import fearless

class WalletCommandProtocolMock: WalletCommandProtocol {
    func execute() throws {}
}
final class WalletCommandFactoryProtocolMock: WalletCommandFactoryProtocol {
    var presentationClosure: ((UIViewController) -> WalletPresentationCommand)?
    var hideClosure: ((WalletDismissAction) -> WalletPresentationCommand)?

    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommand {
        if let closure = presentationClosure {
            return closure(controller)
        } else {
            return WalletPresentationCommand(presentingController: controller)
        }
    }

    func prepareHideCommand(with action: WalletDismissAction) -> WalletPresentationCommand {
        if let closure = hideClosure {
            return closure(action)
        } else {
            return WalletPresentationCommand()
        }
    }
}
