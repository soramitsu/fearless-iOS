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
        presenter.didLoad(view: self)
    }

    func configurePinView() {
        rootView.pinView.delegate = self
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
