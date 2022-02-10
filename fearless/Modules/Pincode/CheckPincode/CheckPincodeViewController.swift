import UIKit
import SoraUI
import SoraFoundation

final class CheckPincodeViewController: UIViewController, ViewHolder, Localizable {
    typealias RootViewType = CheckPincodeViewLayout
    let presenter: PinSetupPresenterProtocol

    init(
        presenter: PinSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
        applyLocalization()
    }

    override func loadView() {
        view = CheckPincodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configurePinView()

        rootView.navigationBar.backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
    }

    func configurePinView() {
        rootView.pinView.mode = .securedInput
        rootView.pinView.delegate = self
        rootView.pinView.characterFieldsView?.numberOfCharacters = 6
        rootView.pinView.securedCharacterFieldsView?.numberOfCharacters = 6
        rootView.pinView.characterFieldsView?.fieldStrokeWidth = 2
        rootView.pinView.securedCharacterFieldsView?.fieldSize = CGSize(width: 15, height: 15)
        rootView.pinView.characterFieldsView?.fieldSpacing = 24
        rootView.pinView.securedCharacterFieldsView?.fieldSpacing = 24
        rootView.pinView.numpadView?.shadowRadius = 36
        rootView.pinView.numpadView?.keyRadius = 36
        rootView.pinView.numpadView?.verticalSpacing = 15
        rootView.pinView.numpadView?.horizontalSpacing = 22
        rootView.pinView.numpadView?.backspaceIcon =
            R.image.pinBackspace()?.tinted(with: .white)?.withRenderingMode(.automatic)
        rootView.pinView.numpadView?.fillColor = .clear
        rootView.pinView.numpadView?.highlightedFillColor = R.color.colorCellSelection()
        rootView.pinView.numpadView?.titleColor = .white
        rootView.pinView.numpadView?.highlightedTitleColor = UIColor(
            red: 255 / 255,
            green: 255 / 255,
            blue: 255 / 255,
            alpha: 0.5
        )
        rootView.pinView.numpadView?.titleFont = R.font.soraRc0040417Regular(size: 25)!
        rootView.pinView.securedCharacterFieldsView?.strokeWidth = 2
        rootView.pinView.securedCharacterFieldsView?.fieldRadius = 6
        rootView.pinView.verticalSpacing = 79
        rootView.pinView.securedCharacterFieldsView?.fillColor = .white
        rootView.pinView.securedCharacterFieldsView?.strokeColor = .white
        rootView.pinView.numpadView?.shadowOpacity = 0
        rootView.pinView.numpadView?.shadowRadius = 0
        rootView.pinView.numpadView?.shadowOffset = CGSize(width: 0, height: 1)
        rootView.pinView.numpadView?.shadowColor = UIColor(
            red: 47 / 255,
            green: 128 / 255,
            blue: 124 / 255,
            alpha: 0.3
        )
        rootView.pinView.numpadView?.supportsAccessoryControl = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization() {
        if let locale = localizationManager?.selectedLocale {
            rootView.locale = locale
        }
    }

    @objc private func closeButtonClicked() {
        presenter.cancel()
    }
}

extension CheckPincodeViewController: PinSetupViewProtocol {
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
        ) { (_: UIAlertAction) -> Void in
            completionBlock(true)
        }

        let skipAction = UIAlertAction(
            title: R.string.localizable.commonSkip(preferredLanguages: languages),
            style: .cancel
        ) { (_: UIAlertAction) -> Void in
            completionBlock(false)
        }

        alertView.addAction(useAction)
        alertView.addAction(skipAction)

        present(alertView, animated: true, completion: nil)
    }

    func didReceiveWrongPincode() {
        rootView.pinView.reset(shouldAnimateError: true)
    }

    func didChangeAccessoryState(enabled: Bool, availableBiometryType: AvailableBiometryType) {
        rootView.pinView.numpadView?.supportsAccessoryControl = enabled
        rootView.pinView.numpadView?.accessoryIcon = availableBiometryType.accessoryIcon?.tinted(
            with: R.color.colorWhite()!
        )
    }
}

extension CheckPincodeViewController: PinViewDelegate {
    func didChange(pinView _: PinView, from _: PinView.CreationState) {}

    func didCompleteInput(pinView _: PinView, result: String) {
        presenter.submit(pin: result)
    }

    func didSelectAccessoryControl(pinView _: PinView) {
        presenter.activateBiometricAuth()
    }

    func didFailConfirmation(pinView _: PinView) {}
}
