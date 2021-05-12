import UIKit

final class ControllerAccountConfirmationInteractor {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!
}

extension ControllerAccountConfirmationInteractor: ControllerAccountConfirmationInteractorInputProtocol {}
