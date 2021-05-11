import UIKit
import CommonWallet
import SoraFoundation

final class StakingRewardDestSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardDestSetupLayout

    let presenter: StakingRewardDestSetupPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingRewardDestSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    var uiFactory: UIFactoryProtocol = UIFactory()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRewardDestSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }
}

extension StakingRewardDestSetupViewController: StakingRewardDestSetupViewProtocol {
    #warning("Not implemented")
}

extension StakingRewardDestSetupViewController: Localizable {
    private func setupLocalization() {
        title = R.string.localizable.stakingRewardDestinationTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
