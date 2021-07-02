import UIKit

final class SignerConnectViewController: UIViewController {
    typealias RootViewType = SignerConnectViewLayout

    let presenter: SignerConnectPresenterProtocol

    init(presenter: SignerConnectPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SignerConnectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SignerConnectViewController: SignerConnectViewProtocol {}
