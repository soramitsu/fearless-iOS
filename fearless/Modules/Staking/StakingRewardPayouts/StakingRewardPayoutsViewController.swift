import UIKit
import SoraFoundation

final class StakingRewardPayoutsViewController: UIViewController {

    // MARK: Properties -
    let presenter: StakingRewardPayoutsPresenterProtocol

    // MARK: Init -
    init(presenter: StakingRewardPayoutsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle -
    override func loadView() {
        view = StakingRewardPayoutsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.stakingRewardPayoutsTitle(preferredLanguages: locale.rLanguages)
    }
}

extension StakingRewardPayoutsViewController: StakingRewardPayoutsViewProtocol {}

extension StakingRewardPayoutsViewController: Localizable {

    private func setupLocalization() {
        setupTitleLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
