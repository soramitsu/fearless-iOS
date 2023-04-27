import UIKit
import PayWingsOAuthSDK

final class PhoneVerificationCodeInteractor {
    // MARK: - Private properties

    private weak var output: PhoneVerificationCodeInteractorOutput?
    private let service: SCKYCService
    private let storage: SCStorage = .shared
    private let eventCenter: EventCenterProtocol
    private let tokenHolder: SCTokenHolderProtocol

    var data: SCKYCUserDataModel
    var callback = SignInWithPhoneNumberVerifyOtpCallback()
    var getUserDataCallback = GetUserDataCallback()
    private let requestOtpCallback = SignInWithPhoneNumberRequestOtpCallback()
    private let otpLength: Int
    private var codeState: SCKYCPhoneCodeState = .editing {
        didSet {
            output?.didReceive(state: codeState)
        }
    }

    init(
        data: SCKYCUserDataModel,
        service: SCKYCService,
        otpLength: Int,
        eventCenter: EventCenterProtocol,
        tokenHolder: SCTokenHolderProtocol
    ) {
        self.service = service
        self.data = data
        self.otpLength = otpLength
        self.eventCenter = eventCenter
        self.tokenHolder = tokenHolder
        callback.delegate = self
        getUserDataCallback.delegate = self
        requestOtpCallback.delegate = self
    }

    private func checkUserStatus(with data: SCKYCUserDataModel) {
        Task {
            var hasFreeAttempts = false
            if case let .success(atempts) = await service.kycAttempts() {
                hasFreeAttempts = atempts.hasFreeAttempts
            }
            let response = await service.kycStatuses()
            await MainActor.run { [weak self, hasFreeAttempts] in
                guard let self else { return }
                switch response {
                case let .success(statuses):
                    let statusesToShow = statuses.filter { $0.userStatus != .userCanceled }
                    if statusesToShow.isEmpty || self.storage.isKYCRetry() && hasFreeAttempts {
                        output?.didReceiveSignInSuccessfulStep(data: data)
                        return
                    }
                    output?.didReceiveUserStatus()
                case .failure:
                    Task { await resetKYC() }
                }
            }
        }
    }

    private func resetKYC() async {
        tokenHolder.removeToken()
        storage.set(isRetry: false)

        await MainActor.run { [weak self] in
            self?.output?.resetKYC()
            self?.eventCenter.notify(with: KYCShouldRestart(data: nil))
        }
    }
}

// MARK: - PhoneVerificationCodeInteractorInput

extension PhoneVerificationCodeInteractor: PhoneVerificationCodeInteractorInput {
    func setup(with output: PhoneVerificationCodeInteractorOutput) {
        self.output = output
    }

    func askToResendCode() {
        service.signInWithPhoneNumberRequestOtp(phoneNumber: data.phoneNumber, callback: requestOtpCallback)
    }

    func verify(code: String) {
        if code.count < otpLength {
            codeState = .editing
            return
        }

        service.signInWithPhoneNumberVerifyOtp(code: code, callback: callback)
    }
}

extension PhoneVerificationCodeInteractor: SignInWithPhoneNumberVerifyOtpCallbackDelegate, SignInWithPhoneNumberRequestOtpCallbackDelegate {
    func onShowOtpInputScreen(otpLength _: Int) {
        codeState = .editing
    }

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
        output?.didReceive(state: codeState)
    }

    func onSignInSuccessful(refreshToken: String, accessToken: String, accessTokenExpirationTime: Int64) {
        let token = SCToken(refreshToken: refreshToken, accessToken: accessToken, accessTokenExpirationTime: accessTokenExpirationTime)
        tokenHolder.set(token: token)

        service.getUserData(callback: getUserDataCallback)
        codeState = .succeed
    }

    func onError(error: PayWingsOAuthSDK.OAuthErrorCode, errorMessage: String?) {
        codeState = .wrong(errorMessage ?? error.description)
    }
}

extension PhoneVerificationCodeInteractor: GetUserDataCallbackDelegate {
    func onUserData(
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        emailConfirmed _: Bool,
        phoneNumber _: String?
    ) {
        data.userId = userId
        data.name = firstName ?? ""
        data.lastname = lastName ?? ""
        data.email = email ?? ""

        checkUserStatus(with: data)
    }
}
