import UIKit

final class ChainAccountViewController: UIViewController {
    typealias RootViewType = ChainAccountViewLayout

    let presenter: ChainAccountPresenterProtocol

    init(presenter: ChainAccountPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChainAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ChainAccountViewController: ChainAccountViewProtocol {}
