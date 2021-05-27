import UIKit

final class CrowdloanContributionConfirmViewController: UIViewController {
    typealias RootViewType = CrowdloanContributionConfirmViewLayout

    let presenter: CrowdloanContributionConfirmPresenterProtocol

    init(presenter: CrowdloanContributionConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanContributionConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CrowdloanContributionConfirmViewController: CrowdloanContributionConfirmViewProtocol {}
