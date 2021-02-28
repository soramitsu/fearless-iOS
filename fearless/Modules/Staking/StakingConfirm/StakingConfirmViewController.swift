import UIKit

final class StakingConfirmViewController: UIViewController {
    var presenter: StakingConfirmPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingConfirmViewController: StakingConfirmViewProtocol {}