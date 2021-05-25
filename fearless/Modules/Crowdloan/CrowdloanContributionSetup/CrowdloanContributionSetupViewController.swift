import UIKit

final class CrowdloanContributionSetupViewController: UIViewController {
    typealias RootViewType = CrowdloanContributionSetupViewLayout

    let presenter: CrowdloanContributionSetupPresenterProtocol

    init(presenter: CrowdloanContributionSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanContributionSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CrowdloanContributionSetupViewController: CrowdloanContributionSetupViewProtocol {}
