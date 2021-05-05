import UIKit

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {}
