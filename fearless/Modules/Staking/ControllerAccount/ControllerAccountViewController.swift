import UIKit

final class ControllerAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountViewLayout

    var presenter: ControllerAccountPresenterProtocol!

    override func loadView() {
        view = ControllerAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ControllerAccountViewController: ControllerAccountViewProtocol {}
