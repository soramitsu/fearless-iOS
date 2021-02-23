import UIKit
import SoraFoundation
import SoraUI
import FearlessUtils
import CommonWallet

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
    @IBOutlet private var actionButton: TriangularedButton!

    private var accountContainerView: UIView?
    private var accountView: DetailsTriangularedView?

    var uiFactory: UIFactoryProtocol!

    private var rewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var amountInputViewModel: AmountInputViewModelProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupInitBalanceView()
        setupInitNetworkFee()
        setupLocalization()
        updateActionButton()

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

    private func setupInitBalanceView() {
        amountInputView.priceText = ""
        amountInputView.balanceText = ""

        let textColor = R.color.colorWhite()!
        let placeholder = NSAttributedString(string: "0",
                                             attributes: [
                                                .foregroundColor: textColor.withAlphaComponent(0.5),
                                                .font: UIFont.h4Title
                                             ])

        amountInputView.textField.attributedPlaceholder = placeholder

        amountInputView.textField.delegate = self
    }

    private func setupInitNetworkFee() {
        feeDetailsLabel.text = ""
        feeActivityIndicator.startAnimating()
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
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: languages)

        applyAsset()
        applyFee()
        applyRewardDestinationViewModel()

        if let accountView = accountView {
            accountView.title = R.string.localizable
                .stakingRewardPayoutAccount(preferredLanguages: languages)
        }

        setupBalanceAccessoryView()
    }

    private func updateActionButton() {
        let isEnabled = (feeViewModel != nil) && (amountInputViewModel?.isValid == true)
        actionButton.isEnabled = isEnabled
    }

    private func applyAsset() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let viewModel = assetViewModel?.value(for: locale) {
            amountInputView.balanceText = R.string.localizable
                .commonBalanceFormat(viewModel.balance ?? "",
                                     preferredLanguages: locale.rLanguages)
            amountInputView.priceText = viewModel.price

            amountInputView.assetIcon = viewModel.icon
            amountInputView.symbol = viewModel.symbol
        }
    }

    private func applyFee() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let fee = feeViewModel?.value(for: locale) {
            feeActivityIndicator.stopAnimating()

            let amountAttributedString = NSMutableAttributedString(string: fee.amount + "  ",
                                                                   attributes: [
                                                                        .foregroundColor: R.color.colorWhite()!,
                                                                        .font: UIFont.p1Paragraph
                                                                   ])

            if let price = fee.price {
                let priceAttributedString = NSAttributedString(string: price,
                                                               attributes: [
                                                                .foregroundColor: R.color.colorGray()!,
                                                                .font: UIFont.p1Paragraph
                                                               ])
                amountAttributedString.append(priceAttributedString)
            }

            feeDetailsLabel.attributedText = amountAttributedString

        } else {
            feeDetailsLabel.text = ""
            feeActivityIndicator.startAnimating()
        }
    }

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

    @IBAction private func actionLearnPayout() {
        presenter.selectLearnMore()
    }

    @IBAction private func actionProceed() {
        presenter.proceed()
    }

    @objc private func actionSelectPayoutAccount() {
        presenter.selectPayoutAccount()
    }
}

extension StakingAmountViewController: StakingAmountViewProtocol {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>) {
        rewardDestinationViewModel = viewModel
        applyRewardDestinationViewModel()
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()

        updateActionButton()
    }

    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>) {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let concreteViewModel = viewModel.value(for: locale)

        amountInputViewModel?.observable.remove(observer: self)

        amountInputViewModel = concreteViewModel

        amountInputView.fieldText = concreteViewModel.displayAmount
        concreteViewModel.observable.add(observer: self)

        updateActionButton()
    }
}

extension StakingAmountViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on view: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on view: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension StakingAmountViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter.updateAmount(amount)
    }
}

extension StakingAmountViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        return amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
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
