import UIKit
import CommonWallet
import FearlessUtils
import SoraFoundation

final class StakingRewardDestSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardDestSetupLayout

    let presenter: StakingRewardDestSetupPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var rewardDestinationViewModel: ChangeRewardDestinationViewModel?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    init(
        presenter: StakingRewardDestSetupPresenterProtocol,
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
        view = StakingRewardDestSetupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupView()

        presenter.setup()
    }

    // MARK: - Actions

    @objc private func actionLearnMore() {
        presenter.displayLearnMore()
    }

    @objc private func actionRestake() {
        if !rootView.restakeOptionView.isSelected {
            presenter.selectRestakeDestination()
        }
    }

    @objc private func actionPayout() {
        if !rootView.payoutOptionView.isSelected {
            presenter.selectPayoutDestination()
        }
    }

    @objc private func actionSelectPayoutAccount() {
        presenter.selectPayoutAccount()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    // MARK: - Private functions

    // MARK: UI changes -

    private func updateAccountView() {
        rootView.accountView.isHidden = rootView.restakeOptionView.isSelected
    }

    private func applyRewardDestinationType(from viewModel: RewardDestinationViewModelProtocol) {
        let activeTextColor = R.color.colorWhite()!
        let inactiveTextColor = R.color.colorLightGray()!

        switch viewModel.type {
        case .restake:
            rootView.restakeOptionView.isSelected = true
            rootView.payoutOptionView.isSelected = false

            rootView.restakeOptionView.titleLabel.textColor = activeTextColor
            rootView.restakeOptionView.amountLabel.textColor = activeTextColor
            rootView.payoutOptionView.titleLabel.textColor = inactiveTextColor
            rootView.payoutOptionView.amountLabel.textColor = inactiveTextColor

            updateAccountView()

        case let .payout(icon, title):
            rootView.restakeOptionView.isSelected = false
            rootView.payoutOptionView.isSelected = true

            rootView.restakeOptionView.titleLabel.textColor = inactiveTextColor
            rootView.restakeOptionView.amountLabel.textColor = inactiveTextColor
            rootView.payoutOptionView.titleLabel.textColor = activeTextColor
            rootView.payoutOptionView.amountLabel.textColor = activeTextColor

            updateAccountView()
            applyPayoutAddress(icon, title: title)
        }

        rootView.restakeOptionView.setNeedsLayout()
        rootView.payoutOptionView.setNeedsLayout()
    }

    private func applyRewardDestinationContent(from viewModel: RewardDestinationViewModelProtocol) {
        if let reward = viewModel.rewardViewModel {
            rootView.restakeOptionView.amountTitle = reward.restakeAmount
            rootView.restakeOptionView.priceTitle = reward.restakePrice
            rootView.restakeOptionView.incomeTitle = reward.restakePercentage
            rootView.payoutOptionView.amountTitle = reward.payoutAmount
            rootView.payoutOptionView.priceTitle = reward.payoutPrice
            rootView.payoutOptionView.incomeTitle = reward.payoutPercentage
        } else {
            rootView.restakeOptionView.amountTitle = ""
            rootView.restakeOptionView.priceTitle = ""
            rootView.restakeOptionView.incomeTitle = ""
            rootView.payoutOptionView.amountTitle = ""
            rootView.payoutOptionView.priceTitle = ""
            rootView.payoutOptionView.incomeTitle = ""
        }
    }

    private func applyPayoutAddress(_ icon: DrawableIcon, title: String) {
        let icon = icon.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        rootView.accountView.iconImage = icon
        rootView.accountView.subtitle = title
    }

    // MARK: Data changes -

    private func applyRewardDestinationViewModel() {
        if let rewardDestViewModel = rewardDestinationViewModel {
            let viewModel = rewardDestViewModel.selectionViewModel.value(for: selectedLocale)
            applyRewardDestinationType(from: viewModel)
            applyRewardDestinationContent(from: viewModel)
        }

        rootView.actionButton.isEnabled = rewardDestinationViewModel?.canApply ?? false
    }

    private func applyFee() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    // MARK: Setup -

    private func setupView() {
        rootView.learnMoreView.addTarget(self, action: #selector(actionLearnMore), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
        rootView.restakeOptionView.addTarget(self, action: #selector(actionRestake), for: .touchUpInside)
        rootView.payoutOptionView.addTarget(self, action: #selector(actionPayout), for: .touchUpInside)
        rootView.accountView.addTarget(self, action: #selector(actionSelectPayoutAccount), for: .touchUpInside)

        rootView.restakeOptionView.isSelected = true
        rootView.payoutOptionView.isSelected = false
    }
}

extension StakingRewardDestSetupViewController: StakingRewardDestSetupViewProtocol {
    func didReceiveRewardDestination(viewModel: ChangeRewardDestinationViewModel?) {
        rewardDestinationViewModel = viewModel
        applyRewardDestinationViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()
    }
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
