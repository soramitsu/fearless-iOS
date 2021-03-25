import UIKit

final class StakingRewardPayoutsViewController: UIViewController {
    var presenter: StakingRewardPayoutsPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingRewardPayoutsViewController: StakingRewardPayoutsViewProtocol {}