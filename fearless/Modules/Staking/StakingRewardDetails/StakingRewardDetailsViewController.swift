import UIKit

final class StakingRewardDetailsViewController: UIViewController {
    var presenter: StakingRewardDetailsPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingRewardDetailsViewController: StakingRewardDetailsViewProtocol {}
