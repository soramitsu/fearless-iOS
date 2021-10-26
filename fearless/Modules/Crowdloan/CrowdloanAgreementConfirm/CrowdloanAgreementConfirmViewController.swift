import UIKit

final class CrowdloanAgreementConfirmViewController: UIViewController {
    typealias RootViewType = CrowdloanAgreementConfirmViewLayout

    let presenter: CrowdloanAgreementConfirmPresenterProtocol

    init(presenter: CrowdloanAgreementConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanAgreementConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CrowdloanAgreementConfirmViewController: CrowdloanAgreementConfirmViewProtocol {}
