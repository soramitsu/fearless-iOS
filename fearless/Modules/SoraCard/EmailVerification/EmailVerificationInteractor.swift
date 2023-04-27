import UIKit
import PayWingsOAuthSDK

final class EmailVerificationInteractor {
    // MARK: - Private properties

    private weak var output: EmailVerificationInteractorOutput?
    private let service: SCKYCService
    private let data: SCKYCUserDataModel
    private let tokenHolder: SCTokenHolderProtocol

    private let unverifiedEmailCallback = ChangeUnverifiedEmailCallback()
    private let registerUserCallback = RegisterUserCallback()
    private let checkEmailCallback = CheckEmailVerifiedCallback()
    private let sendNewVerificationEmailCallback = SendNewVerificationEmailCallback()
    private var timer = Timer()

    init(service: SCKYCService, data: SCKYCUserDataModel, tokenHolder: SCTokenHolderProtocol) {
        self.service = service
        self.data = data
        self.tokenHolder = tokenHolder

        unverifiedEmailCallback.delegate = self
        registerUserCallback.delegate = self
        checkEmailCallback.delegate = self
        sendNewVerificationEmailCallback.delegate = self
    }
}

// MARK: - EmailVerificationInteractorInput

extension EmailVerificationInteractor: EmailVerificationInteractorInput {
    func setup(with output: EmailVerificationInteractorOutput) {
        self.output = output
    }

    func process(email: String) {
        data.lastEmailOTPSentDate = Date()
        data.email = email

        service.registerUser(data: data, callback: registerUserCallback)
    }

    private func changeEmail(email: String) {
        data.lastEmailOTPSentDate = Date()
        data.email = email

        service.changeUnverifiedEmail(email: email, callback: unverifiedEmailCallback)
    }

    func resendVerificationLink() {
        data.lastEmailOTPSentDate = .init()

        service.sendNewVerificationEmail(callback: sendNewVerificationEmailCallback)
    }

    private func startEmailVerificationChecks() {
        timer.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(requestCheckEmailVerified),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func requestCheckEmailVerified() {
        service.checkEmailVerified(callback: checkEmailCallback)
    }
}

extension EmailVerificationInteractor: ChangeUnverifiedEmailCallbackDelegate, RegisterUserCallbackDelegate, SendNewVerificationEmailCallbackDelegate, CheckEmailVerifiedCallbackDelegate {
    func onEmailNotVerified() {}

    func onSignInSuccessful(refreshToken: String, accessToken: String, accessTokenExpirationTime: Int64) {
        timer.invalidate()
        let token = SCToken(
            refreshToken: refreshToken,
            accessToken: accessToken,
            accessTokenExpirationTime: accessTokenExpirationTime
        )
        tokenHolder.set(token: token)
        output?.didReceiveSignInSuccessfulStep(data: data)
    }

    func onShowEmailConfirmationScreen(email _: String, autoEmailSent: Bool) {
        startEmailVerificationChecks()

        output?.didReceiveConfirmationRequired(data: data, autoEmailSent: autoEmailSent)
    }

    func onUserSignInRequired() {
        output?.didReceiveSignInRequired()
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage _: String?) {
        output?.didReceiveError(error: error)
    }
}
