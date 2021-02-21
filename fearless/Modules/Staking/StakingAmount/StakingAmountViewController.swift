import UIKit
import SoraFoundation
import SoraUI
import FearlessUtils

final class StakingAmountViewController: UIViewController, AdaptiveDesignable {
    var presenter: StakingAmountPresenterProtocol!

    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var amountTitleLabel: UILabel!
    @IBOutlet private var amountInputView: AmountInputView!
    @IBOutlet private var feeTitleLabel: UILabel!
    @IBOutlet private var feeDetailsLabel: UILabel!
    @IBOutlet private var feeActivityIndicator: UIActivityIndicatorView!
    @IBOutlet private var rewardDestinationTitleLabel: UILabel!
    @IBOutlet private var restakeView: RewardSelectionView!
    @IBOutlet private var payoutView: RewardSelectionView!
    @IBOutlet private var chooseRewardView: UIView!
    @IBOutlet private var learnMoreView: DetailsTriangularedView!

    private var accountContainerView: UIView?
    private var accountView: DetailsTriangularedView?

    var uiFactory: UIFactoryProtocol!

    private var rewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupNavigationItem() {
        let closeBarItem = UIBarButtonItem(image: R.image.iconClose(),
                                                style: .plain,
                                                target: self,
                                                action: #selector(actionClose))

        navigationItem.leftBarButtonItem = closeBarItem
    }

    @objc private func actionClose() {
        presenter.close()
    }

    // MARK: Private

    private func createAccountViewIfNeeded() {
        guard accountContainerView == nil else {
            return
        }

        let accountView = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: false)
        accountView.translatesAutoresizingMaskIntoConstraints = false
        self.accountView = accountView

        accountView.highlightedFillColor = R.color.colorHighlightedPink()!

        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages
        accountView.title = R.string.localizable
            .stakingRewardPayoutAccount(preferredLanguages: languages)

        accountView.actionImage = R.image.iconMore()

        accountView.addTarget(self,
                              action: #selector(actionSelectPayoutAccount),
                              for: .touchUpInside)

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.addSubview(accountView)
        self.accountContainerView = containerView

        accountView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                             constant: UIConstants.horizontalInset).isActive = true

        accountView.rightAnchor.constraint(equalTo: containerView.rightAnchor,
                                           constant: -UIConstants.horizontalInset).isActive = true

        accountView.heightAnchor.constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true

        accountView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12.0).isActive = true
        accountView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0.0).isActive = true
    }

    private func updateAccountView() {
        if restakeView.isSelected, let containerView = accountContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()

            accountContainerView = nil
            accountView = nil
        }

        if payoutView.isSelected {
            createAccountViewIfNeeded()

            if let containerView = accountContainerView,
               let insertionIndex = stackView.arrangedSubviews
                .firstIndex(where: { $0 == chooseRewardView }) {
                stackView.insertArrangedSubview(containerView, at: insertionIndex + 1)
            }
        }
    }

    private func setupBalanceAccessoryView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let accessoryView = uiFactory.createAmountAccessoryView(for: self, locale: locale)
        amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupLocalization() {
        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages

        title = R.string.localizable.stakingSetupTitle(preferredLanguages: languages)
        amountTitleLabel.text = R.string.localizable.stakingAmountTitle(preferredLanguages: languages)
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)
        feeTitleLabel.text = R.string.localizable
            .commonNetworkFee(preferredLanguages: languages)
        rewardDestinationTitleLabel.text = R.string.localizable
            .stakingRewardDestinationChoose(preferredLanguages: languages)
        restakeView.title = R.string.localizable.stakingRestakeTitle(preferredLanguages: languages)
        restakeView.subtitle = R.string.localizable
            .stakingRewardRestakeSubtitle(preferredLanguages: languages)
        restakeView.earningsSubtitle = R.string.localizable
            .stakingRewardDestinationDesc(preferredLanguages: languages)
        payoutView.title = R.string.localizable.stakingPayoutTitle(preferredLanguages: languages)
        payoutView.subtitle = R.string.localizable
            .stakingPayoutSubtitle(preferredLanguages: languages)
        payoutView.earningsSubtitle = R.string.localizable
            .stakingRewardDestinationDesc(preferredLanguages: languages)
        learnMoreView.title = R.string.localizable
            .stakingPayoutsLearnMore(preferredLanguages: languages)

        applyRewardDestinationViewModel()

        if let accountView = accountView {
            accountView.title = R.string.localizable
                .stakingRewardPayoutAccount(preferredLanguages: languages)
        }

        setupBalanceAccessoryView()
    }

    // MARK: Reward Destination

    private func applyRewardDestinationViewModel() {
        if let rewardDestViewModel = rewardDestinationViewModel {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let viewModel = rewardDestViewModel.value(for: locale)
            applyRewardDestinationType(from: viewModel)
            applyRewardDestinationContent(from: viewModel)
        }
    }

    private func applyRewardDestinationContent(from viewModel: RewardDestinationViewModelProtocol) {
        let restakeColor = restakeView.isSelected ? R.color.colorWhite()! : R.color.colorLightGray()!

        let restakeAmount = NSMutableAttributedString(string: viewModel.restakeAmount + "  ",
                                                      attributes: [
                                                        .foregroundColor: restakeColor,
                                                        .font: UIFont.h6Title
                                                      ])

        let restakePercentage = NSAttributedString(string: viewModel.restakePercentage,
                                                   attributes: [
                                                    .foregroundColor: R.color.colorGreen()!,
                                                    .font: UIFont.h6Title
                                                   ])

        restakeAmount.append(restakePercentage)

        let payoutColor = payoutView.isSelected ? R.color.colorWhite()! : R.color.colorLightGray()!

        let payoutAmount = NSMutableAttributedString(string: viewModel.payoutAmount + "  ",
                                                     attributes: [
                                                        .foregroundColor: payoutColor,
                                                        .font: UIFont.h6Title
                                                     ])

        let payoutPercentage = NSAttributedString(string: viewModel.payoutPercentage,
                                                  attributes: [
                                                    .foregroundColor: R.color.colorGreen()!,
                                                    .font: UIFont.h6Title
                                                  ])
        payoutAmount.append(payoutPercentage)

        restakeView.earningsTitleLabel.attributedText = restakeAmount
        payoutView.earningsTitleLabel.attributedText = payoutAmount

        restakeView.titleLabel.textColor = restakeColor
        payoutView.titleLabel.textColor = payoutColor
    }

    private func applyRewardDestinationType(from viewModel: RewardDestinationViewModelProtocol) {
        switch viewModel.type {
        case .restake:
            restakeView.isSelected = true
            payoutView.isSelected = false

            updateAccountView()
        case .payout(let icon, let title):
            restakeView.isSelected = false
            payoutView.isSelected = true

            updateAccountView()
            applyPayoutAddress(icon, title: title)
        }
    }

    private func applyPayoutAddress(_ icon: DrawableIcon, title: String) {
        let icon = icon.imageWithFillColor(R.color.colorWhite()!,
                                           size: UIConstants.smallAddressIconSize,
                                           contentScale: UIScreen.main.scale)

        accountView?.iconImage = icon
        accountView?.subtitle = title
    }

    @IBAction private func actionRestake() {
        if !restakeView.isSelected {
            presenter.selectRestakeDestination()
        }
    }

    @IBAction private func actionPayout() {
        if !payoutView.isSelected {
            presenter.selectPayoutDestination()
        }
    }

    @objc private func actionSelectPayoutAccount() {
        presenter.selectPayoutAccount()
    }
}

extension StakingAmountViewController: StakingAmountViewProtocol {}

extension StakingAmountViewController: AmountInputAccessoryViewDelegate {
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>) {
        rewardDestinationViewModel = viewModel
        applyRewardDestinationViewModel()
    }

    func didSelect(on view: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on view: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension StakingAmountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
