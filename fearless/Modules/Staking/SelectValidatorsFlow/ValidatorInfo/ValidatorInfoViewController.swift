import UIKit
import SoraFoundation

final class ValidatorInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorInfoViewLayout

    var presenter: ValidatorInfoPresenterProtocol

    // MARK: Lifecycle -

    init(presenter: ValidatorInfoPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ValidatorInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable
            .stakingValidatorInfoTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

// MARK: - ValidatorInfoViewProtocol

extension ValidatorInfoViewController: ValidatorInfoViewProtocol {
    func didRecieve(viewModel: ValidatorInfoViewModel) {
        rootView.bind(viewModel: viewModel, locale: selectedLocale)
    }
}

// MARK: - Localizable

extension ValidatorInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
