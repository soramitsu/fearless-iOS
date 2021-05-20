import UIKit

final class CrowdloanListViewController: UIViewController {
    typealias RootViewType = CrowdloanListViewLayout

    let presenter: CrowdloanListPresenterProtocol

    init(presenter: CrowdloanListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CrowdloanListViewController: CrowdloanListViewProtocol {}
