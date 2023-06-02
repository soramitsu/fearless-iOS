import UIKit
import SoraFoundation
import SoraUI
import FearlessUtils
import CommonWallet

final class StakingAmountViewController: UIViewController, AdaptiveDesignable, LoadableViewProtocol {
    var presenter: StakingAmountPresenterProtocol?

    @IBOutlet private var inputContainerView: UIView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var amountInputView: AmountInputView!
    @IBOutlet private var rewardDestinationTitleLabel: UILabel!
    @IBOutlet private var restakeView: RewardSelectionView!
    @IBOutlet private var payoutView: RewardSelectionView!
    @IBOutlet private var chooseRewardView: UIView!
    @IBOutlet private var learnMoreView: DetailsTriangularedView!
    @IBOutlet private var actionButton: TriangularedButton!

    @IBOutlet var yourRewardDestinationContainer: UIView!
    @IBOutlet var yourRewardDestinationLabel: UILabel!
    @IBOutlet var rewardDestinationView: RewardSelectionView!
    @IBOutlet var rewardAccountView: DetailsTriangularedView!

    private lazy var networkFeeView = uiFactory.createNetworkFeeView()

    private var accountContainerView: UIView?
    private var accountView: DetailsTriangularedView?

    var uiFactory: UIFactoryProtocol!

    private var yourRewardDestinationViewModel: LocalizableResource<YourRewardDestinationViewModel>?
    private var rewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var amountInputViewModel: IAmountInputViewModel?
    private var viewModel: StakingAmountMainViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupInitBalanceView()
        setupInitNetworkFee()
        setupLocalization()
        setupYourRewardDestinationView()
        updateActionButton()

        presenter?.setup()
    }

    private func setupNavigationItem() {
        let closeBarItem = UIBarButtonItem(
            image: R.image.iconClose(),
            style: .plain,
            target: self,
            action: #selector(actionClose)
        )

        navigationItem.leftBarButtonItem = closeBarItem
    }

    @objc private func actionClose() {
        presenter?.close()
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

        accountView.actionImage = R.image.iconSmallArrowDown()

        accountView.addTarget(
            self,
            action: #selector(actionSelectPayoutAccount),
            for: .touchUpInside
        )

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.addSubview(accountView)

        accountContainerView = containerView

        accountView.leadingAnchor.constraint(
            equalTo: containerView.leadingAnchor,
            constant: UIConstants.horizontalInset
        ).isActive = true

        accountView.rightAnchor.constraint(
            equalTo: containerView.rightAnchor,
            constant: -UIConstants.horizontalInset
        ).isActive = true

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

                containerView.widthAnchor.constraint(
                    equalTo: stackView.widthAnchor,
                    constant: 0.0
                ).isActive = true
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
        let placeholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: textColor.withAlphaComponent(0.5),
                .font: UIFont.h4Title
            ]
        )

        amountInputView.textField.attributedPlaceholder = placeholder
        amountInputView.textField.keyboardType = .decimalPad

        amountInputView.textField.delegate = self
    }

    private func setupInitNetworkFee() {
        guard let index = stackView.arrangedSubviews.firstIndex(of: inputContainerView) else {
            return
        }

        stackView.insertArrangedSubview(networkFeeView, at: index + 1)
        stackView.setCustomSpacing(10.0, after: inputContainerView)

        networkFeeView.translatesAutoresizingMaskIntoConstraints = false
        networkFeeView.widthAnchor.constraint(
            equalTo: stackView.widthAnchor,
            constant: -2 * UIConstants.horizontalInset
        ).isActive = true

        networkFeeView.bind(viewModel: nil)
    }

    func setupYourRewardDestinationView() {
        rewardAccountView.fillColor = R.color.colorDarkGray()!
        rewardAccountView.highlightedFillColor = R.color.colorHighlightedPink()!
        rewardAccountView.strokeColor = .clear
        rewardAccountView.highlightedStrokeColor = .clear
        rewardAccountView.borderWidth = 1.0
        rewardAccountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        rewardAccountView.actionImage = R.image.iconMore()
        rewardAccountView.titleLabel.textColor = R.color.colorLightGray()!
        rewardAccountView.titleLabel.font = UIFont.p2Paragraph
        rewardAccountView.subtitleLabel?.textColor = R.color.colorWhite()!
        rewardAccountView.subtitleLabel?.font = UIFont.p1Paragraph
        rewardAccountView.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)
        rewardAccountView.iconRadius = UIConstants.triangularedIconSmallRadius

        rewardDestinationView.fillColor = R.color.colorDarkGray()!
        rewardDestinationView.highlightedFillColor = R.color.colorDarkGray()!
        rewardDestinationView.strokeColor = R.color.colorWhite()!
        rewardDestinationView.highlightedStrokeColor = R.color.colorWhite()!
        rewardDestinationView.borderWidth = 0.0
        rewardDestinationView.isSelected = true
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        title = R.string.localizable.stakingStake(preferredLanguages: languages)
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)
        rewardDestinationTitleLabel.text = R.string.localizable
            .stakingSetupRewardDestinationSectionTitle(preferredLanguages: languages)
        restakeView.title = R.string.localizable.stakingSetupRestakeTitle(preferredLanguages: languages)
        payoutView.title = R.string.localizable.stakingSetupPayoutTitle(preferredLanguages: languages)
        learnMoreView.title = R.string.localizable
            .stakingRewardsLearnMore(preferredLanguages: languages)
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: languages)

        networkFeeView.locale = locale

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
        let isEnabled = (amountInputViewModel?.isValid == true) && viewModel?.continueAvailable == true
        actionButton.set(enabled: isEnabled)
    }

    private func applyAsset() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        if let viewModel = assetViewModel?.value(for: locale) {
            amountInputView.balanceText = R.string.localizable
                .commonAvailableFormat(
                    viewModel.balance ?? "",
                    preferredLanguages: locale.rLanguages
                )
            amountInputView.priceText = viewModel.price

            amountInputView.symbol = viewModel.symbol

            viewModel.iconViewModel?.loadAmountInputIcon(on: amountInputView.iconView, animated: true)
        }
    }

    private func applyFee() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let fee = feeViewModel?.value(for: locale)
        networkFeeView.bind(viewModel: fee)
    }

    private func applyRewardDestinationViewModel() {
        chooseRewardView.isHidden = rewardDestinationViewModel == nil

        guard let rewardDestViewModel = rewardDestinationViewModel else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let viewModel = rewardDestViewModel.value(for: locale)
        applyRewardDestinationType(from: viewModel)
        applyRewardDestinationContent(from: viewModel)
    }

    private func applyRewardDestinationContent(from viewModel: RewardDestinationViewModelProtocol) {
        let restakeColor = restakeView.isSelected ? R.color.colorWhite()! : R.color.colorLightGray()!
        let payoutColor = payoutView.isSelected ? R.color.colorWhite()! : R.color.colorLightGray()!

        if let reward = viewModel.rewardViewModel {
            restakeView.amountTitle = reward.restakeAmount
            restakeView.incomeTitle = reward.restakePercentage
            restakeView.priceTitle = reward.restakePrice
            payoutView.amountTitle = reward.payoutAmount
            payoutView.incomeTitle = reward.payoutPercentage
            payoutView.priceTitle = reward.payoutPrice
        } else {
            restakeView.amountTitle = ""
            restakeView.priceTitle = ""
            restakeView.incomeTitle = ""
            payoutView.amountTitle = ""
            payoutView.priceTitle = ""
            payoutView.incomeTitle = ""
        }

        restakeView.titleLabel.textColor = restakeColor
        restakeView.amountLabel.textColor = restakeColor
        payoutView.titleLabel.textColor = payoutColor
        payoutView.amountLabel.textColor = payoutColor
        restakeView.isHidden = !(viewModel.rewardViewModel?.restakeAvailable == true)

        restakeView.setNeedsLayout()
        payoutView.setNeedsLayout()
    }

    private func applyRewardDestinationType(from viewModel: RewardDestinationViewModelProtocol) {
        switch viewModel.type {
        case .restake:
            restakeView.isSelected = true
            payoutView.isSelected = false

            updateAccountView()
        case let .payout(icon, title, _):
            restakeView.isSelected = false
            payoutView.isSelected = true

            updateAccountView()
            applyPayoutAddress(icon, title: title)
        }
    }

    private func applyYourRewardDestinationViewModel(_ viewModel: LocalizableResource<YourRewardDestinationViewModel>?) {
        yourRewardDestinationContainer.isHidden = yourRewardDestinationViewModel == nil

        guard let localizableViewModel = viewModel?.value(for: selectedLocale) else {
            return
        }

        rewardDestinationView.amountTitle = localizableViewModel.payoutAmount
        rewardDestinationView.incomeTitle = localizableViewModel.payoutPercentage
        rewardDestinationView.priceTitle = localizableViewModel.payoutPrice

        rewardAccountView.iconImage = R.image.iconFearlessRounded()
        rewardAccountView.subtitle = localizableViewModel.accountViewModel.name
        rewardAccountView.title = localizableViewModel.accountViewModel.title
        rewardAccountView.actionImage = nil
    }

    private func applyPayoutAddress(_ icon: DrawableIcon?, title: String) {
        let icon = icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        accountView?.iconImage = icon
        accountView?.subtitle = title
    }

    @IBAction private func actionRestake() {
        if !restakeView.isSelected {
            presenter?.selectRestakeDestination()
        }
    }

    @IBAction private func actionPayout() {
        if !payoutView.isSelected {
            presenter?.selectPayoutDestination()
        }
    }

    @IBAction private func actionLearnPayout() {
        presenter?.selectLearnMore()
    }

    @IBAction private func actionProceed() {
        presenter?.proceed()
    }

    @objc private func actionSelectPayoutAccount() {
        presenter?.selectPayoutAccount()
    }
}

extension StakingAmountViewController: StakingAmountViewProtocol {
    func didReceive(viewModel: StakingAmountMainViewModel) {
        self.viewModel = viewModel

        chooseRewardView.isHidden = viewModel.rewardDestinationViewModel == nil

        if let assetViewModel = viewModel.assetViewModel {
            didReceiveAsset(viewModel: assetViewModel)
        }

        if let rewardDestinationViewModel = viewModel.rewardDestinationViewModel {
            didReceiveRewardDestination(viewModel: rewardDestinationViewModel)
        }

        if let feeViewModel = viewModel.feeViewModel {
            didReceiveFee(viewModel: feeViewModel)
        }

        if let inputViewModel = viewModel.inputViewModel {
            didReceiveInput(viewModel: inputViewModel)
        }

        updateActionButton()
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assetViewModel = viewModel
        applyAsset()
    }

    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>) {
        rewardDestinationViewModel = viewModel
        applyRewardDestinationViewModel()
    }

    func didReceiveYourRewardDestination(viewModel: LocalizableResource<YourRewardDestinationViewModel>) {
        yourRewardDestinationViewModel = viewModel
        applyYourRewardDestinationViewModel(viewModel)
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFee()

        updateActionButton()
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
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
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        presenter?.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

extension StakingAmountViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountInputView.fieldText = amountInputViewModel?.displayAmount

        updateActionButton()

        let amount = amountInputViewModel?.decimalAmount ?? 0.0
        presenter?.updateAmount(amount)
    }
}

extension StakingAmountViewController: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        amountInputViewModel?.didReceiveReplacement(string, for: range) ?? false
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
