import UIKit
import SoraFoundation

final class StakingUnbondConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingUnbondConfirmLayout

    let presenter: StakingUnbondConfirmPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    init(
        presenter: StakingUnbondConfirmPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
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
        view = StakingUnbondConfirmLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirmTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension StakingUnbondConfirmViewController: StakingUnbondConfirmViewProtocol {}

extension StakingUnbondConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
