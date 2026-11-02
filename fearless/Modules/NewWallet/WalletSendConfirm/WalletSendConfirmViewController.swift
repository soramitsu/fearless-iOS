import UIKit
import SoraFoundation

final class WalletSendConfirmViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = WalletSendConfirmViewLayout

    let presenter: WalletSendConfirmPresenterProtocol

    private var state: WalletSendConfirmViewState = .loading

    init(presenter: WalletSendConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletSendConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        presenter.setup()

        rootView.navigationBar.backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        rootView.receiverWarningButton.addTarget(self, action: #selector(handleScamWarningTapped), for: .touchUpInside)
        rootView.confirmButton.addTarget(self, action: #selector(continueButtonClicked), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (presenter as? WalletSendConfirmScopeManaging)?.resumeSendReview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let scope = presenter as? WalletSendConfirmScopeManaging
        let navigatedAway = isMovingFromParent || isBeingDismissed ||
            navigationController?.isBeingDismissed == true ||
            (navigationController != nil && navigationController?.topViewController !== self)
        let ownedSheet = presentedViewController is SheetAletViewController &&
            scope?.hasOwnedRecoveryPresentation == true
        if navigatedAway || !ownedSheet {
            scope?.suspendSendReview()
        }
    }

    @objc private func applicationDidEnterBackground() {
        (presenter as? WalletSendConfirmScopeManaging)?.suspendSendReview()
    }

    @objc private func applicationDidBecomeActive() {
        guard viewIfLoaded?.window != nil,
              navigationController == nil || navigationController?.topViewController === self else { return }
        (presenter as? WalletSendConfirmScopeManaging)?.resumeSendReview()
    }

    private func setupLocalization() {
        rootView.locale = selectedLocale
    }

    private func applyState(_ state: WalletSendConfirmViewState) {
        self.state = state

        switch state {
        case .loading:
            break
        case let .loaded(model):
            rootView.bind(confirmViewModel: model)
        }
    }

    @objc private func continueButtonClicked() {
        presenter.didTapConfirmButton()
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    @objc private func handleScamWarningTapped() {
        presenter.didTapScamWarningButton()
    }
}

extension WalletSendConfirmViewController: WalletSendConfirmViewProtocol {
    func didReceive(state: WalletSendConfirmViewState) {
        applyState(state)
    }

    func didReceive(isLoading: Bool) {
        rootView.confirmButton.set(loading: isLoading)

        if !isLoading {
            rootView.confirmButton.set(enabled: true, changeStyle: true)
        }
    }
}

extension WalletSendConfirmViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded, FWAppearance.sendPresentationRestyled else { return }
        setupLocalization()
    }
}

extension WalletSendConfirmViewLayout {
    func setupAdaptiveLayout() {
        contentView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
        confirmButton.removeFromSuperview()
        contentView.stackView.addArrangedSubview(confirmButton)
        confirmButton.snp.remakeConstraints { $0.width.equalTo(safeAreaLayoutGuide).offset(-2 * UIConstants.bigOffset) }
        contentView.stackView.layoutMargins.bottom = UIConstants.bigOffset
        amountLabel.numberOfLines = 0
        amountLabel.lineBreakMode = .byCharWrapping
        amountLabel.snp.makeConstraints { $0.width.equalTo(safeAreaLayoutGuide).offset(-2 * UIConstants.bigOffset) }
        [senderView, receiverView, amountView, feeView, tipView, accountCreationView].forEach { $0.snp.removeConstraints() }
        receiverStack.alignment = .top
        receiverWarningButton.snp.makeConstraints { $0.size.equalTo(44) }
        navigationBar.titleLabel.numberOfLines = 0
        navigationBar.titleLabel.textAlignment = .center
        updateTypography()
    }

    func updateTypography() {
        guard FWAppearance.sendPresentationRestyled else { return }
        amountLabel.font = .fw(.displayL, locale: locale, compatibleWith: traitCollection)
        navigationBar.titleLabel.font = .fw(.titleM, locale: locale, compatibleWith: traitCollection)
        updateNavigationTitleLayout()
        senderView.configureSendReview(locale: locale, traits: traitCollection, topStyle: .bodyL, bottomStyle: .monoM)
        receiverView.configureSendReview(locale: locale, traits: traitCollection, topStyle: .monoM, bottomStyle: .monoM)
        [amountView, feeView, tipView, accountCreationView].forEach {
            $0.configureSendReview(locale: locale, traits: traitCollection, topStyle: .numberL, bottomStyle: .numberM)
        }
        networkView.refreshPresentation(locale: locale)
        confirmButton.configureWrappingTitle(locale: locale, compatibleWith: traitCollection)
        setNeedsLayout()
    }

    func updateNavigationTitleLayout() {
        navigationBar.configureSendTitle(
            navigationBar.titleLabel, in: contentView.stackView, traits: traitCollection
        )
    }

    func localizeAmount() {
        guard let currentModel else { return }
        let value = currentModel.amountString
        let title = R.string.localizable.sendConfirmAmountTitle(value, preferredLanguages: locale.rLanguages)
        let attributed = NSMutableAttributedString(string: title)
        attributed.addAttribute(
            .foregroundColor, value: R.color.colorWhite()!, range: (title as NSString).range(of: value)
        )
        amountLabel.attributedText = attributed
    }

    func applyLocalization() {
        senderView.titleLabel.text = R.string.localizable.transactionDetailsFrom(
            preferredLanguages: locale.rLanguages
        )
        receiverView.titleLabel.text = R.string.localizable.walletSendReceiverTitle(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.commonPreview(
            preferredLanguages: locale.rLanguages
        ))
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: locale.rLanguages
        )
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        tipView.titleLabel.text = R.string.localizable.walletSendTipTitle(
            preferredLanguages: locale.rLanguages
        )
        accountCreationView.titleLabel.text = R.string.localizable.solanaTransferAccount_creationTitle(
            preferredLanguages: locale.rLanguages
        )
        applyAccountCreationNote()
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
        if FWAppearance.sendPresentationRestyled {
            localizeAmount()
            updateTypography()
        }
    }
}

extension BaseNavigationBar {
    /// Oversized headings scroll with the form, keeping Back and the keyboard viewport available.
    func configureSendTitle(_ label: UILabel, in contentStack: UIStackView, traits: UITraitCollection) {
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .center
        let sideInset = UIConstants.bigOffset + LayoutConstants.backButtonSize + UIConstants.defaultOffset
        let availableWidth = max(1, bounds.width - 2 * sideInset)
        let titleHeight = label.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude)).height
        let expanded = traits.preferredContentSizeCategory.isAccessibilityCategory ||
            (bounds.width > 0 && titleHeight > LayoutConstants.backButtonSize)
        let destination = expanded ? contentStack : centerStackView
        if label.superview !== destination {
            (label.superview as? UIStackView)?.removeArrangedSubview(label)
            label.removeFromSuperview()
            label.snp.removeConstraints()
            if expanded {
                contentStack.insertArrangedSubview(label, at: 0)
                label.snp.makeConstraints { $0.width.equalTo(self).offset(-2 * UIConstants.bigOffset) }
            } else {
                setCenterViews([label])
            }
        }
        label.setContentCompressionResistancePriority(expanded ? .required : .defaultHigh, for: .vertical)
    }
}
