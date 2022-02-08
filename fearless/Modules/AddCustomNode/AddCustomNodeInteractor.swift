import UIKit

final class AddCustomNodeInteractor {
    weak var presenter: AddCustomNodeInteractorOutputProtocol!
}

extension AddCustomNodeInteractor: AddCustomNodeInteractorInputProtocol {}
