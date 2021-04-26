import UIKit
import SoraFoundation

final class YourValidatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = YourValidatorsViewLayout

    var presenter: YourValidatorsPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var viewState: YourValidatorsViewState?

    init(presenter: YourValidatorsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension YourValidatorsViewController: YourValidatorsViewProtocol {
    func reload(state _: YourValidatorsViewState) {}
}

extension YourValidatorsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
