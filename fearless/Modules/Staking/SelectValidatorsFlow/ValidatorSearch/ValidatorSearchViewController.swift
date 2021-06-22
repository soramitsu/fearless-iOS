import UIKit
import SoraFoundation

final class ValidatorSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorSearchViewLayout

    let presenter: ValidatorSearchPresenterProtocol

    // MARK: - Lifecycle

    init(
        presenter: ValidatorSearchPresenterProtocol,
        localizationManager: LocalizationManager
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
        view = ValidatorSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.setup()
    }

    // MARK: - Private functions
}

extension ValidatorSearchViewController: ValidatorSearchViewProtocol {}

extension ValidatorSearchViewController: Localizable {
    func applyLocalization() {
        #warning("Not implemented")
    }
}
