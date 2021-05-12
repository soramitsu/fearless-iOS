import UIKit

final class ControllerAccountConfirmationViewController: UIViewController {
    var presenter: ControllerAccountConfirmationPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ControllerAccountConfirmationViewController: ControllerAccountConfirmationViewProtocol {}
