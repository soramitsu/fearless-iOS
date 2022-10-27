import UIKit
import SoraUI

protocol ApplicationStatusPresentable: AnyObject {
    func presentStatus(with viewModel: ApplicationStatusViewViewModel, animated: Bool)
    func dismissStatus(with viewModel: ApplicationStatusViewViewModel?, animated: Bool)
}

extension ApplicationStatusPresentable {
    func presentStatus(
        with viewModel: ApplicationStatusViewViewModel,
        animated: Bool
    ) {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return
        }
        window.presentStatus(with: viewModel, animated: animated)
    }

    func dismissStatus(
        with viewModel: ApplicationStatusViewViewModel?,
        animated: Bool
    ) {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return
        }
        window.dismissStatus(with: viewModel, animated: animated)
    }
}
