import UIKit
import SoraUI

protocol ApplicationStatusPresentable: AnyObject {
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool)
    func dismissStatus(with viewModel: ApplicationStatusAlertEvent?, animated: Bool)
}

extension ApplicationStatusPresentable {
    func presentStatus(
        with viewModel: ApplicationStatusAlertEvent,
        animated: Bool
    ) {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return
        }
        window.presentStatus(with: viewModel, animated: animated)
    }

    func dismissStatus(
        with viewModel: ApplicationStatusAlertEvent?,
        animated: Bool
    ) {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return
        }
        window.dismissStatus(with: viewModel, animated: animated)
    }
}
