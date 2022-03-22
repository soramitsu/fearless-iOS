import UIKit

final class WarningAlertInteractor {
    weak var presenter: WarningAlertInteractorOutputProtocol?
}

extension WarningAlertInteractor: WarningAlertInteractorInputProtocol {}
