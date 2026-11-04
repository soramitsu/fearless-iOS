import UIKit
import SoraUI
import SoraFoundation

class PinSetupViewController: UIViewController, AdaptiveDesignable, NavigationDependable {
    var presenter: PinSetupPresenterProtocol!
    var mode = PinView.Mode.create

    var cancellable: Bool = false

    var mainViewAccessibilityId: String? = "MainViewAccessibilityId"
    var bgViewAccessibilityId: String? = "BgViewAccessibilityId"
    var inputFieldAccessibilityId: String? = "InputFieldAccessibilityId"
    var keyPrefixAccessibilityId: String? = "KeyPrefixAccessibilityId"
    var backspaceAccessibilityId: String? = "BackspaceAccessibilityId"

    var localizableTopTitle: LocalizableResource<String> = LocalizableResource { _ in "" }

    weak var navigationControlling: NavigationControlling?

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var pinView: PinView!

    @IBOutlet private var navigationBar: UINavigationBar!

    @IBOutlet private var navigationBarTop: NSLayoutConstraint!
    @IBOutlet private var pinViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var pinViewCenterConstraint: NSLayoutConstraint!

    private var cancelButton: UIButton?
    private var authorizationDeparturePending = false
    private let contentScrollView = UIScrollView()
    private let saveErrorLabel = UILabel()

    @IBOutlet var topLabel: UILabel!

    // MARK: View Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        configurePinView()

        if cancellable {
            configureCancelButton()
        }

        setupLocalization()
        configureScrollableContent()
        setupAccessibilityIdentifiers()

        presenter.didLoad(view: self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyAdaptiveContentColumnOutsideNavigation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true else { return }
        if mode == .create {
            presenter.cancel()
        } else {
            authorizationDeparturePending = true
            presenter.willLeaveView()
            transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] context in
                guard let self, context.isCancelled, self.authorizationDeparturePending else { return }
                self.authorizationDeparturePending = false
                self.presenter.didCancelLeavingView()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard authorizationDeparturePending else { return }
        authorizationDeparturePending = false
        presenter.didLeaveView()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateNavigationBarTopInset()
    }

    // MARK: Configure

    private func configureNavigationBar() {
        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.shadowImage = UIImage()
        navigationBar.tintColor = R.color.colorWhite()!
        navigationBar.delegate = self

        updateNavigationBarTopInset()
    }

    private func updateNavigationBarTopInset() {
        let statusBarHeight = SceneWindowFinder.statusBarHeight(from: view.window?.windowScene)
        navigationBarTop.constant = max(statusBarHeight, view.safeAreaInsets.top)
    }

    private func configureCancelButton() {
        let cancelButton = UIButton()
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitleColor(R.color.colorWhite()!, for: .normal)
        cancelButton.titleLabel?.numberOfLines = 0
        cancelButton.titleLabel?.textAlignment = .center
        cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true

        cancelButton.addTarget(
            self,
            action: #selector(actionCancel),
            for: .touchUpInside
        )

        self.cancelButton = cancelButton
    }

    private func updateTitleLabelState() {
        let languages = localizationManager?.preferredLocalizations

        if pinView.mode == .create {
            if pinView.creationState == .normal {
                titleLabel.text = R.string.localizable
                    .createNewPincode(preferredLanguages: languages)
            } else {
                titleLabel.text = R.string.localizable
                    .pincodeConfirmPinCode(preferredLanguages: languages)
            }
        } else {
            titleLabel.text = R.string.localizable
                .pincodeEnterPinCode(preferredLanguages: languages)
        }
    }

    private func configurePinView() {
        pinView.mode = mode
        pinView.delegate = self

        pinView.numpadView?.accessoryIcon = pinView.numpadView?.accessoryIcon?.tinted(with: R.color.colorWhite()!)
        pinView.numpadView?.backspaceIcon = pinView.numpadView?.backspaceIcon?.tinted(with: R.color.colorWhite()!)
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        cancelButton?.setTitle(
            R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
            for: .normal
        )

        saveErrorLabel.text = R.string.localizable.pincodeSaveFailed(preferredLanguages: locale.rLanguages)
        topLabel.text = localizableTopTitle.value(for: locale)

        updateTitleLabelState()
        updateTypography()
    }

    // MARK: Accessibility

    private func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = mainViewAccessibilityId
        pinView.setupInputField(accessibilityId: inputFieldAccessibilityId)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: keyPrefixAccessibilityId)
        pinView.numpadView?.setupBackspace(accessibilityId: backspaceAccessibilityId)
    }

    // MARK: Layout

    private func configureScrollableContent() {
        // Keep the existing PIN control and its input delegates. Only its layout
        // moves out of the fixed-height nib constraints into scrollable content.
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        saveErrorLabel.numberOfLines = 0
        saveErrorLabel.textAlignment = .center
        saveErrorLabel.textColor = R.color.colorWhite()
        saveErrorLabel.accessibilityIdentifier = "PinSaveFailure"
        saveErrorLabel.isHidden = true
        for element in [topLabel, titleLabel, saveErrorLabel, pinView].compactMap({ $0 }) {
            element.removeFromSuperview()
            element.setContentCompressionResistancePriority(.required, for: .vertical)
            content.addArrangedSubview(element)
        }
        if let cancelButton = cancelButton {
            content.addArrangedSubview(cancelButton)
        }
        for label in [topLabel, titleLabel].compactMap({ $0 }) {
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.textAlignment = .center
        }
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.contentInsetAdjustmentBehavior = .never
        contentScrollView.alwaysBounceVertical = false
        contentScrollView.addSubview(content)
        view.addSubview(contentScrollView)
        NSLayoutConstraint.activate([
            contentScrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(
                equalTo: contentScrollView.contentLayoutGuide.trailingAnchor, constant: -16
            ),
            content.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func updateTypography() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        topLabel.font = .fw(.titleM, locale: locale, compatibleWith: traitCollection)
        titleLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        saveErrorLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        cancelButton?.titleLabel?.font = .fw(.labelL, locale: locale, compatibleWith: traitCollection)
        let weight: UIFont.Weight = traitCollection.legibilityWeight == .bold ? .semibold : .regular
        let digits = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 25, weight: weight), compatibleWith: traitCollection
        )
        pinView.numpadView?.titleFont = digits
        pinView.numpadView?.keyRadius = max(28, ceil(digits.lineHeight / 2 + 8))
        pinView.numpadView?.horizontalSpacing = 12
        pinView.numpadView?.verticalSpacing = 12
        pinView.verticalSpacing = 24
        pinView.invalidateLayout()
        view.setNeedsLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded else { return }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            updateTypography()
        }
    }

    // MARK: Action

    @objc func actionCancel() {
        presenter.cancel()
    }
}

extension PinSetupViewController: PinSetupViewProtocol {
    func resetAuthenticationInput() {
        pinView.reset(shouldAnimateError: false)
    }

    func didFailSavingPin() {
        pinView.resetCreationState(animated: false)
        updateTitleLabelState()
        saveErrorLabel.isHidden = false
        view.layoutIfNeeded()
        contentScrollView.scrollRectToVisible(
            saveErrorLabel.convert(saveErrorLabel.bounds, to: contentScrollView), animated: false
        )
        UIAccessibility.post(notification: .announcement, argument: saveErrorLabel.text)
    }

    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {
        var title: String?
        var message: String?

        let languages = localizationManager?.selectedLocale.rLanguages

        switch biometryType {
        case .touchId:
            title = R.string.localizable.askTouchidTitle(preferredLanguages: languages)
            message = R.string.localizable.askTouchidMessage(preferredLanguages: languages)
        case .faceId:
            title = R.string.localizable.askFaceidTitle(preferredLanguages: languages)
            message = R.string.localizable.askFaceidMessage(preferredLanguages: languages)
        case .none:
            completionBlock(true)
            return
        }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string.localizable.commonUse(preferredLanguages: languages),
            style: .default
        ) { (_: UIAlertAction) in
            completionBlock(true)
        }

        let skipAction = UIAlertAction(
            title: R.string.localizable.commonSkip(preferredLanguages: languages),
            style: .cancel
        ) { (_: UIAlertAction) in
            completionBlock(false)
        }

        alertView.addAction(useAction)
        alertView.addAction(skipAction)

        present(alertView, animated: true, completion: nil)
    }

    func didReceiveWrongPincode() {
        if mode != .create {
            pinView?.reset(shouldAnimateError: true)
        }
    }

    func didChangeAccessoryState(enabled: Bool, availableBiometryType: AvailableBiometryType) {
        pinView?.numpadView?.supportsAccessoryControl = enabled
        pinView?.numpadView?.accessoryIcon = availableBiometryType.accessoryIcon?.tinted(
            with: R.color.colorWhite()!
        )
    }
}

extension PinSetupViewController: PinViewDelegate {
    func didFailConfirmation(pinView _: PinView) {}

    func didCompleteInput(pinView _: PinView, result: String) {
        presenter.submit(pin: result)
    }

    func didChange(pinView: PinView, from _: PinView.CreationState) {
        updateTitleLabelState()

        let shouldAnimate = navigationControlling == nil
        if pinView.creationState == .confirm {
            navigationControlling?.setNavigationBarHidden(true, animated: false)
            navigationBar.pushItem(UINavigationItem(), animated: shouldAnimate)
        } else {
            navigationControlling?.setNavigationBarHidden(false, animated: false)
            navigationBar.popItem(animated: shouldAnimate)
        }
    }

    func didSelectAccessoryControl(pinView _: PinView) {
        presenter.activateBiometricAuth()
    }
}

extension PinSetupViewController: UINavigationBarDelegate {
    func navigationBar(_: UINavigationBar, shouldPop _: UINavigationItem) -> Bool {
        if pinView.creationState == .confirm {
            navigationControlling?.setNavigationBarHidden(false, animated: false)
        }

        pinView.resetCreationState(animated: true)
        updateTitleLabelState()
        return true
    }
}

extension PinSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
