import UIKit

final class SignerConfirmViewController: UIViewController {
    typealias RootViewType = SignerConfirmViewLayout

    let presenter: SignerConfirmPresenterProtocol

    init(presenter: SignerConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SignerConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SignerConfirmViewController: SignerConfirmViewProtocol {}