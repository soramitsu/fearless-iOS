import UIKit
import SoraFoundation

final class StakingRewardDetailsViewController: UIViewController, ViewHolder {

    typealias RootViewType = StakingRewardDetailsViewLayout

    let presenter: StakingRewardDetailsPresenterProtocol

    init(presenter: StakingRewardDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        presenter.setup()
    }
}

extension StakingRewardDetailsViewController: StakingRewardDetailsViewProtocol {}

extension StakingRewardDetailsViewController: Localizable {

    private func setupLocalization() {
        setupTitleLocalization()
        setupButtonLocalization()
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }

    private func setupTitleLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.stakingRewardDetailsTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupButtonLocalization() {
        let title = R.string.localizable.stakingRewardDetailsPayout()
        rootView.payoutButton.imageWithTitleView?.title = title
    }
}
