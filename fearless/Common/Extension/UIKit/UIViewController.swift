import UIKit

extension UIViewController {
    var topModalViewController: UIViewController {
        var presentingController = self

        while let nextPresentingController = presentingController.presentedViewController {
            presentingController = nextPresentingController
        }

        return presentingController
    }

    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
