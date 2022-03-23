import UIKit

final class ManageAssetsViewController: UIViewController {
    typealias RootViewType = ManageAssetsViewLayout

    let presenter: ManageAssetsPresenterProtocol

    init(presenter: ManageAssetsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ManageAssetsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ManageAssetsViewController: ManageAssetsViewProtocol {}