import UIKit
import PayWingsOAuthSDK

final class PhoneVerificationInteractor {
    // MARK: - Private properties

    private weak var output: PhoneVerificationInteractorOutput?

    private let service: SCKYCService
    private let data = SCKYCUserDataModel()
    private let callback = SignInWithPhoneNumberRequestOtpCallback()

    init(service: SCKYCService) {
        self.service = service
        callback.delegate = self
    }
}

// MARK: - PhoneVerificationInteractorInput

extension PhoneVerificationInteractor: PhoneVerificationInteractorInput {
    func requestVerificationCode(phoneNumber: String) {
        data.phoneNumber = phoneNumber
        data.lastPhoneOTPSentDate = Date()

        service.signInWithPhoneNumberRequestOtp(
            phoneNumber: phoneNumber,
            callback: callback
        )
    }

    func setup(with output: PhoneVerificationInteractorOutput) {
        self.output = output
    }
}

extension PhoneVerificationInteractor: SignInWithPhoneNumberRequestOtpCallbackDelegate {
    func onShowOtpInputScreen(otpLength: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.output?.didProceed(with: strongSelf.data, otpLength: otpLength)
        }
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage _: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.output?.didReceive(oAuthError: error)
        }
    }
}
