import UIKit
import SoraFoundation

final class SignerConfirmViewController: UIViewController {
    typealias RootViewType = SignerConfirmViewLayout

    let presenter: SignerConfirmPresenterProtocol

    init(presenter: SignerConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
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

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {}
}

extension SignerConfirmViewController: SignerConfirmViewProtocol {
    func didReceiveCall(viewModel: SignerConfirmCallViewModel) {

    }

    func didReceiveFee(viewModel: SignerConfirmFeeViewModel) {
        
    }
}

extension SignerConfirmViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
