import UIKit
import SoraFoundation

final class StakingRewardPayoutsViewController: UIViewController {
    var presenter: StakingRewardPayoutsPresenterProtocol!

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
