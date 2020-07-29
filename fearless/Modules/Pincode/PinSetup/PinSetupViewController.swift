import UIKit
import SoraUI
import SoraFoundation

class PinSetupViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static var cancelBottomMargin: CGFloat = 30.0
    }

    var presenter: PinSetupPresenterProtocol!
    var mode = PinView.Mode.create

    var cancellable: Bool = false

    var mainViewAccessibilityId: String? = "MainViewAccessibilityId"
    var bgViewAccessibilityId: String? = "BgViewAccessibilityId"
    var inputFieldAccessibilityId: String? = "InputFieldAccessibilityId"
    var keyPrefixAccessibilityId: String? = "KeyPrefixAccessibilityId"
    var backspaceAccessibilityId: String? = "BackspaceAccessibilityId"

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var pinView: PinView!

    @IBOutlet private var navigationBar: UINavigationBar!

    @IBOutlet private var navigationBarTop: NSLayoutConstraint!
    @IBOutlet private var titleTopConstraint: NSLayoutConstraint!
    @IBOutlet private var pinViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var pinViewBottomConstraint: NSLayoutConstraint!

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private var cancelButton: UIButton?

    // MARK: View Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        configurePinView()

        if cancellable {
            configureCancelButton()
        }

        setupLocalization()
        adjustLayoutConstraints()
        setupAccessibilityIdentifiers()

        presenter.start()
    }

    // MARK: Configure

    private func configureNavigationBar() {
        navigationBarTop.constant = UIApplication.shared.statusBarFrame.size.height

        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.shadowImage = UIImage()
        navigationBar.tintColor = R.color.colorWhite()!
        navigationBar.delegate = self
    }

    private func configureCancelButton() {
        let cancelButton = UIButton()
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let bottomMargin = -Constants.cancelBottomMargin * designScaleRatio.height

        if #available(iOS 11.0, *) {
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                 constant: bottomMargin).isActive = true
        } else {
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor,
                                                 constant: bottomMargin).isActive = true
        }

        cancelButton.trailingAnchor.constraint(equalTo: pinView.trailingAnchor).isActive = true

        cancelButton.setTitleColor(R.color.colorWhite()!, for: .normal)
        cancelButton.titleLabel?.font = UIFont.p1Paragraph

        cancelButton.addTarget(self,
                               action: #selector(actionCancel),
                               for: .touchUpInside)

        self.cancelButton = cancelButton
    }

    private func updateTitleLabelState() {
        let languages = localizationManager?.preferredLocalizations

        if pinView.mode == .create {
            if  pinView.creationState == .normal {
                titleLabel.text = R.string.localizable
                    .pincodeSetYourPinCode(preferredLanguages: languages)
            } else {
                titleLabel.text = R.string.localizable
                    .pincodeConfirmYourPinCode(preferredLanguages: languages)
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
        let languages = localizationManager?.preferredLocalizations
        cancelButton?.setTitle(R.string.localizable.commonCancel(preferredLanguages: languages),
                               for: .normal)

        updateTitleLabelState()
    }

    // MARK: Accessibility

    private func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = mainViewAccessibilityId
        pinView.setupInputField(accessibilityId: inputFieldAccessibilityId)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: keyPrefixAccessibilityId)
        pinView.numpadView?.setupBackspace(accessibilityId: backspaceAccessibilityId)
    }

    // MARK: Layout

    private func adjustLayoutConstraints() {
        let designScaleRatio = self.designScaleRatio

        if isAdaptiveHeightDecreased || isAdaptiveWidthDecreased {
            let scale = min(designScaleRatio.width, designScaleRatio.height)

            if let numpadView = pinView.numpadView {
                pinView.numpadView?.keyRadius *= scale

                if let titleFont = numpadView.titleFont {
                    numpadView.titleFont = UIFont(name: titleFont.fontName, size: scale * titleFont.pointSize)
                }
            }

            if let currentFieldsView = pinView.characterFieldsView {
                let font = currentFieldsView.fieldFont

                if let newFont = UIFont(name: font.fontName, size: scale * font.pointSize) {
                    currentFieldsView.fieldFont = newFont
                }
            }

            pinView.securedCharacterFieldsView?.fieldRadius *= scale
        }

        if isAdaptiveHeightDecreased {
            pinView.verticalSpacing *= designScaleRatio.height

            if let cancelButton = cancelButton {
                pinView.verticalSpacing -= cancelButton.intrinsicContentSize.height
            }

            pinView.numpadView?.verticalSpacing *= designScaleRatio.height
            pinView.characterFieldsView?.fieldSize.height *= designScaleRatio.height
            pinView.securedCharacterFieldsView?.fieldSize.height *= designScaleRatio.height
        }

        if isAdaptiveWidthDecreased {
            pinView.numpadView?.horizontalSpacing *= designScaleRatio.width
            pinView.characterFieldsView?.fieldSize.width *= designScaleRatio.width
            pinView.securedCharacterFieldsView?.fieldSize.width *= designScaleRatio.width
        }

        titleTopConstraint.constant *= designScaleRatio.height
        pinViewTopConstraint.constant *= designScaleRatio.height

        pinViewBottomConstraint.constant *= designScaleRatio.height

        if cancellable {
            let cancelMargin = Constants.cancelBottomMargin * designScaleRatio.height
            titleTopConstraint.constant -= cancelMargin
            pinViewBottomConstraint.constant += cancelMargin
        }
    }

    // MARK: Action

    @objc func actionCancel() {
        presenter.cancel()
    }
}

extension PinSetupViewController: PinSetupViewProtocol {
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

        let useAction = UIAlertAction(title: R.string.localizable.commonUse(preferredLanguages: languages),
                                      style: .default) { (_: UIAlertAction) -> Void in
            completionBlock(true)
        }

        let skipAction = UIAlertAction(title: R.string.localizable.commonSkip(preferredLanguages: languages),
                                       style: .cancel) { (_: UIAlertAction) -> Void in
            completionBlock(false)
        }

        alertView.addAction(useAction)
        alertView.addAction(skipAction)

        self.present(alertView, animated: true, completion: nil)
    }

    func didReceiveWrongPincode() {
        if mode != .create {
            pinView?.reset(shouldAnimateError: true)
        }
    }

    func didChangeAccessoryState(enabled: Bool) {
        pinView?.numpadView?.supportsAccessoryControl = enabled
    }
}

extension PinSetupViewController: PinViewDelegate {
    func didCompleteInput(pinView: PinView, result: String) {
        presenter.submit(pin: result)
    }

    func didChange(pinView: PinView, from state: PinView.CreationState) {
        updateTitleLabelState()
        if pinView.creationState == .confirm {
            navigationBar.pushItem(UINavigationItem(), animated: true)
        } else {
            navigationBar.popItem(animated: true)
        }
    }

    func didSelectAccessoryControl(pinView: PinView) {
        presenter.activateBiometricAuth()
    }
}

extension PinSetupViewController: UINavigationBarDelegate {
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
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
