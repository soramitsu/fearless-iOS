import UIKit

final class CustomValidatorListInteractor {
    weak var presenter: CustomValidatorListInteractorOutputProtocol!
}

extension CustomValidatorListInteractor: CustomValidatorListInteractorInputProtocol {}
