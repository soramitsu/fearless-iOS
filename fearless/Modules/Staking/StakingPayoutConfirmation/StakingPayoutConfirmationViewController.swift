import UIKit

final class StakingPayoutConfirmationViewController: UIViewController {

    let presenter: StakingPayoutConfirmationPresenterProtocol

    init(presenter: StakingPayoutConfirmationPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingPayoutConfirmationViewController: StakingPayoutConfirmationViewProtocol {}
