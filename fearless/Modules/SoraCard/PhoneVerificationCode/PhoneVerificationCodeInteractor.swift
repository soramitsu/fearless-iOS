import UIKit
import PayWingsOAuthSDK

final class PhoneVerificationCodeInteractor {
    // MARK: - Private properties

    private weak var output: PhoneVerificationCodeInteractorOutput?
    private let data: SCKYCUserDataModel
    private let service: SCKYCService
    private var callback = SignInWithPhoneNumberVerifyOtpCallback()
    private let otpLength: Int
    private var codeState: SCKYCPhoneCodeState = .editing {
        didSet {
            output?.didReceive(state: codeState)
        }
    }

    init(data: SCKYCUserDataModel, service: SCKYCService, otpLength: Int) {
        self.service = service
        self.data = data
        self.otpLength = otpLength
        callback.delegate = self
    }
}

// MARK: - PhoneVerificationCodeInteractorInput

extension PhoneVerificationCodeInteractor: PhoneVerificationCodeInteractorInput {
    func setup(with output: PhoneVerificationCodeInteractorOutput) {
        self.output = output
    }

    func verify(code: String) {
        if code.count < otpLength {
            codeState = .editing
            return
        }

        service.signInWithPhoneNumberVerifyOtp(code: code, callback: callback)
    }
}

extension PhoneVerificationCodeInteractor: SignInWithPhoneNumberVerifyOtpCallbackDelegate {
    func onShowEmailConfirmationScreen(email: String, autoEmailSent _: Bool) {
        data.email = email
        codeState = .succeed

        output?.didReceiveEmailVerificationStep(data: data)
    }

    func onShowRegistrationScreen() {
        codeState = .succeed

        output?.didReceiveUserRegistrationStep(data: data)
    }

    func onUserSignInRequired() {
        // TODO: needed?
    }

    func onVerificationFailed() {
        codeState = .wrong("Incorrect or expired OTP")
    }

    func onSignInSuccessful(refreshToken: String, accessToken: String, accessTokenExpirationTime _: Int64) {
        SCStorage.shared.add(accessToken: accessToken)
        SCStorage.shared.add(refreshToken: refreshToken)
        SCAPIClient.shared.set(accessToken: accessToken, refreshToken: refreshToken)
        codeState = .succeed

        output?.didReceiveSignInSuccessfulStep(data: data)
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        codeState = .wrong(errorMessage ?? error.description)
    }
}
