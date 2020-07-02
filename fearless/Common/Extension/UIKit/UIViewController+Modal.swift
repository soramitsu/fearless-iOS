import UIKit

extension UIViewController {
    var topModalViewController: UIViewController {
        var presentingController = self

        while let nextPresentingController = presentingController.presentedViewController {
            presentingController = nextPresentingController
        }

        return presentingController
    }
}
