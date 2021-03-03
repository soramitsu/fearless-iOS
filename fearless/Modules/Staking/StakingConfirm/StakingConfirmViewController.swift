import UIKit
import SoraUI
import SoraFoundation

final class StakingConfirmViewController: UIViewController {
    var presenter: StakingConfirmPresenterProtocol!

    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var accountView: DetailsTriangularedView!
    @IBOutlet private var balanceView: AmountInputView!
    @IBOutlet private var rewardTitleLabel: UILabel!
    @IBOutlet private var rewardDetailsLabel: UILabel!
    @IBOutlet private var rewardContainerView: UIView!
    @IBOutlet private var validatorsView: DetailsTriangularedView!
    @IBOutlet private var validatorsDetailLabel: UILabel!
    @IBOutlet private var feeTitleLabel: UILabel!
    @IBOutlet private var feeDetailsLabel: UILabel!
    @IBOutlet private var actionButton: TriangularedButton!
    @IBOutlet private var activityIndicatorView: UIActivityIndicatorView!

    var uiFactory: UIFactoryProtocol!

    private var payoutContainerView: UIView?
    private var payoutView: DetailsTriangularedView?

    private var confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = localizationManager?.selectedLocale.rLanguages

        title = R.string.localizable.stakingConfirmTitle(preferredLanguages: languages)

        accountView.title = R.string.localizable.stakingStashTitle(preferredLanguages: languages)

        actionButton.imageWithTitleView?.title =
            R.string.localizable.commonConfirm(preferredLanguages: languages)
        actionButton.invalidateLayout()

        balanceView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        validatorsView.title = R.string.localizable
            .stakingRecommendedValidatorsTitle(preferredLanguages: languages)

        rewardTitleLabel.text = R.string.localizable
            .stakingRewardDestinationTitle(preferredLanguages: languages)
        feeTitleLabel.text = R.string.localizable.commonNetworkFee(preferredLanguages: languages)

        applyConfirmationViewModel()
        applyBalanceView()
        applyFeeViewModel()
    }

    private func createPayoutView() {
        let payoutView = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        payoutView.translatesAutoresizingMaskIntoConstraints = false
        self.payoutView = payoutView

        payoutView.highlightedFillColor = R.color.colorHighlightedPink()!

        let languages = (localizationManager?.selectedLocale ?? Locale.current).rLanguages
        payoutView.title = R.string.localizable
            .stakingRewardPayoutAccount(preferredLanguages: languages)

        payoutView.actionImage = R.image.iconMore()

        payoutView.addTarget(self,
                             action: #selector(actionOnPayoutAccount),
                             for: .touchUpInside)

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.addSubview(payoutView)
        self.payoutContainerView = containerView

        payoutView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                             constant: UIConstants.horizontalInset).isActive = true

        payoutView.rightAnchor.constraint(equalTo: containerView.rightAnchor,
                                          constant: -UIConstants.horizontalInset).isActive = true

        payoutView.heightAnchor.constraint(equalToConstant: UIConstants.triangularedViewHeight)
            .isActive = true

        payoutView.topAnchor.constraint(equalTo: containerView.topAnchor,
                                        constant: 0.0).isActive = true

        payoutView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor,
                                           constant: -12.0).isActive = true
    }

    private func updateActionButton() {
        let isEnabled = (assetViewModel != nil)
        actionButton.isEnabled = isEnabled
    }

    private func insertPayoutViewIfNeeded() {
        guard payoutContainerView == nil else {
            return
        }

        createPayoutView()

        if let containerView = payoutContainerView,
           let insertionIndex = stackView.arrangedSubviews
             .firstIndex(where: { $0 == rewardContainerView }) {
             stackView.insertArrangedSubview(containerView, at: insertionIndex + 1)
        }
    }

    private func removePayoutViewIfNeeded() {
        if let containerView = payoutContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()

            payoutContainerView = nil
            payoutView = nil
        }
    }

    private func applyConfirmationViewModel() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        guard let viewModel = confirmationViewModel?.value(for: locale) else {
            return
        }

        balanceView.fieldText = viewModel.amount

        accountView.iconImage = viewModel.senderIcon
            .imageWithFillColor(R.color.colorWhite()!,
                                size: UIConstants.smallAddressIconSize,
                                contentScale: UIScreen.main.scale)
        accountView.subtitle = viewModel.senderName

        switch viewModel.rewardDestination {
        case .restake:
            rewardDetailsLabel.text = R.string.localizable
                .stakingRestakeTitle(preferredLanguages: locale.rLanguages)
            removePayoutViewIfNeeded()
        case .payout(let icon, let title):
            rewardDetailsLabel.text = R.string.localizable
                .stakingPayoutTitle(preferredLanguages: locale.rLanguages)
            insertPayoutViewIfNeeded()

            payoutView?.iconImage = icon.imageWithFillColor(R.color.colorWhite()!,
                                                            size: UIConstants.smallAddressIconSize,
                                                            contentScale: UIScreen.main.scale)
            payoutView?.subtitle = title
        }

        validatorsDetailLabel.text = "\(viewModel.validatorsCount)"
    }

    private func applyBalanceView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        guard let viewModel = assetViewModel?.value(for: locale) else {
            return
        }

        balanceView.balanceText = R.string.localizable
            .commonBalanceFormat(viewModel.balance ?? "",
                                 preferredLanguages: locale.rLanguages)
        balanceView.priceText = viewModel.price

        balanceView.assetIcon = viewModel.icon
        balanceView.symbol = viewModel.symbol
    }

    private func applyFeeViewModel() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let viewModel = feeViewModel?.value(for: locale) {
            activityIndicatorView.stopAnimating()
            feeDetailsLabel.isHidden = false

            let amountAttributedString = NSMutableAttributedString(string: viewModel.amount + "  ",
                                                                   attributes: [
                                                                        .foregroundColor: R.color.colorWhite()!,
                                                                        .font: UIFont.p1Paragraph
                                                                   ])

            if let price = viewModel.price {
                let priceAttributedString = NSAttributedString(string: price,
                                                               attributes: [
                                                                .foregroundColor: R.color.colorGray()!,
                                                                .font: UIFont.p1Paragraph
                                                               ])
                amountAttributedString.append(priceAttributedString)
            }

            feeDetailsLabel.attributedText = amountAttributedString
        } else {
            feeDetailsLabel.isHidden = true
            activityIndicatorView.startAnimating()
        }
    }

    // MARK: Action

    @objc private func actionOnPayoutAccount() {
        presenter.selectPayoutAccount()
    }

    @IBAction private func actionOnWalletAccount() {
        presenter.selectWalletAccount()
    }

    @IBAction private func proceed() {
        presenter.proceed()
    }

    @IBAction private func actionSelectedValidators() {
        presenter.selectValidators()
    }
}

extension StakingConfirmViewController: StakingConfirmViewProtocol {
    func didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>) {
        self.confirmationViewModel = confirmationViewModel
        applyConfirmationViewModel()
    }

    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        self.assetViewModel = assetViewModel
        applyBalanceView()
        updateActionButton()
    }

    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel
        self.applyFeeViewModel()
    }
}

extension StakingConfirmViewController {
    func applyLocalization() {
        if isViewLoaded {
            applyLocalization()
            view.setNeedsLayout()
        }
    }
}
