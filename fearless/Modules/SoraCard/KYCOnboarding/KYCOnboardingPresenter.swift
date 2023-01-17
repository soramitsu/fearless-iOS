import Foundation
import SoraFoundation
import AVFoundation
import PayWingsOAuthSDK
import PayWingsOnboardingKYC

final class KYCOnboardingPresenter {
    // MARK: Private properties

    private weak var view: KYCOnboardingViewInput?
    private let router: KYCOnboardingRouterInput
    private let interactor: KYCOnboardingInteractorInput
    private let logger: LoggerProtocol

    // MARK: - Constructors

    init(
        interactor: KYCOnboardingInteractorInput,
        router: KYCOnboardingRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkMicrophonePermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
                if granted == true {
                    self.checkMicrophonePermission()
                } else {
                    self.showPhoneSettings(type: PermissionType.camera.rawValue)
                }
            })
        case .denied:
            showPhoneSettings(type: PermissionType.camera.rawValue)
        case .restricted:
            return
        default:
            fatalError(NSLocalizedString("Camera Authorization Status not handled!", comment: "Status: \(AVCaptureDevice.authorizationStatus(for: .video))"))
        }
    }

    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            onAllPermissionsGranted()
        case .denied:
            showPhoneSettings(type: PermissionType.microphone.rawValue)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    self.onAllPermissionsGranted()
                } else {
                    self.showPhoneSettings(type: PermissionType.microphone.rawValue)
                }
            }
        default:
            fatalError(NSLocalizedString(
                "Microphone Authorization Status not handled!",
                comment: "Status: \(AVAudioSession.sharedInstance().recordPermission)"
            ))
        }
    }

    private func showPhoneSettings(type: String) {
        let settingsAction = SheetAlertPresentableAction(
            title: R.string.localizable.tabbarSettingsTitle(preferredLanguages: selectedLocale.rLanguages)) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: { _ in })
            }
        }

        let alertViewModel = SheetAlertPresentableViewModel(
            title: "Permission Error",
            message: "Permission for \(type) access denied, please allow our app permission through Settings in your phone if you want to use our service.",
            actions: [settingsAction],
            closeAction: R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)
        )

        router.present(viewModel: alertViewModel, from: view)
    }

    private func onAllPermissionsGranted() {
        interactor.requestKYCSettings()
    }

    private func presentBreakingError(message: String) {
        let closeAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages))
        { [weak self] in
            self?.router.dismiss(view: self?.view)
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: "KYC Failed",
            message: message,
            actions: [closeAction],
            closeAction: nil
        )

        router.present(viewModel: viewModel, from: view)
    }
}

// MARK: - KYCOnboardingViewOutput

extension KYCOnboardingPresenter: KYCOnboardingViewOutput {
    func didLoad(view: KYCOnboardingViewInput) {
        self.view = view
        interactor.setup(with: self)

        checkCameraPermission()
    }
}

// MARK: - KYCOnboardingInteractorOutput

extension KYCOnboardingPresenter: KYCOnboardingInteractorOutput {
    func didReceive(config: PayWingsOnboardingKYC.KycConfig, result: PayWingsOnboardingKYC.VerificationResult) {
        view?.didReceiveStartKycTrigger(with: config, result: result)
    }

    func didReceive(error: Error) {
        presentBreakingError(message: error.localizedDescription)

        logger.error("error: \(error.localizedDescription)")
    }

    func didReceive(kycError: PayWingsOnboardingKYC.ErrorEvent) {
        let errorMessage = "\(kycError.StatusDescription) (\(kycError.StatusCode))"
        presentBreakingError(message: errorMessage)

        logger.error("kycError: \(kycError.StatusCode), description: \(kycError.StatusDescription)")
    }

    func didReceive(result _: PayWingsOnboardingKYC.SuccessEvent) {}

    func didReceive(oAuthError: OAuthErrorCode, message: String?) {
        let errorMessage = "\(message ?? "") (\(oAuthError.description))"
        presentBreakingError(message: errorMessage)

        logger.error("oAuthError: \(oAuthError), description: \(message ?? "")")
    }
}

// MARK: - Localizable

extension KYCOnboardingPresenter: Localizable {
    func applyLocalization() {}
}

extension KYCOnboardingPresenter: KYCOnboardingModuleInput {}
