import UIKit
import SoraFoundation

final class ControllerAccountConfirmationVC: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountConfirmationLayout

    let presenter: ControllerAccountConfirmationPresenterProtocol

    init(
        presenter: ControllerAccountConfirmationPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ControllerAccountConfirmationLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ControllerAccountConfirmationVC: ControllerAccountConfirmationViewProtocol {}

extension ControllerAccountConfirmationVC: Localizable {
    func applyLocalization() {}
}
