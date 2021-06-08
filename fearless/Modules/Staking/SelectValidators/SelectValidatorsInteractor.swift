import UIKit

final class SelectValidatorsInteractor {
    weak var presenter: SelectValidatorsInteractorOutputProtocol!
}

extension SelectValidatorsInteractor: SelectValidatorsInteractorInputProtocol {}
