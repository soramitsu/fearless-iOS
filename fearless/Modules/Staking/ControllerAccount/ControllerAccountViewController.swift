import UIKit

final class ControllerAccountViewController: UIViewController {
    var presenter: ControllerAccountPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ControllerAccountViewController: ControllerAccountViewProtocol {}
