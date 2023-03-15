import Foundation
import PayWingsOAuthSDK

enum SCEndpoint: Endpoint {
    case getReferenceNumber
    case kycStatus

    var path: String {
        switch self {
        case .getReferenceNumber:
            return "get-reference-number"
        case .kycStatus:
            return "kyc-status"
        }
    }
}

final class SCKYCService {
    internal let client: SCAPIClient
    private let payWingsOAuthClient: PayWingsOAuthSDK.OAuthServiceProtocol

    init(client: SCAPIClient) {
        self.client = client

        let domain = "soracard.com"
        let apiKey = "6974528a-ee11-4509-b549-a8d02c1aec0d"
        PayWingsOAuthClient.initialize(environmentType: .TEST, apiKey: apiKey, domain: domain)

        payWingsOAuthClient = PayWingsOAuthClient.instance()!
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = SCStorage.shared.refreshToken() else { return }
        try await withCheckedThrowingContinuation { continuation in
            self.payWingsOAuthClient.getNewAccessToken(refreshToken: refreshToken) { [weak self] result in
                if let accessToken = result.accessTokenData?.accessToken {
                    SCStorage.shared.add(accessToken: accessToken)
                    self?.client.set(accessToken: accessToken)
                    continuation.resume()
                    return
                }

                if let errorData = result.errorData {
                    continuation.resume(throwing: NSError(
                        domain: "SCKYCService",
                        code: errorData.error.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: errorData.errorMessage ?? ""]
                    ))
                    return
                }
                continuation.resume()
            }
        }
    }

    func getUserData(callback: GetUserDataCallback) {
        payWingsOAuthClient.getUserData(accessToken: client.accessToken, callback: callback)
    }

    func sendNewVerificationEmail(callback: SendNewVerificationEmailCallback) {
        payWingsOAuthClient.sendNewVerificationEmail(callback: callback)
    }

    func registerUser(data: SCKYCUserDataModel, callback: RegisterUserCallback) {
        payWingsOAuthClient.registerUser(
            firstName: data.name,
            lastName: data.lastname,
            email: data.email,
            callback: callback
        )
    }

    func changeUnverifiedEmail(email: String, callback: ChangeUnverifiedEmailCallback) {
        payWingsOAuthClient.changeUnverifiedEmail(email: email, callback: callback)
    }

    func signInWithPhoneNumberVerifyOtp(code: String, callback: SignInWithPhoneNumberVerifyOtpCallback) {
        payWingsOAuthClient.signInWithPhoneNumberVerifyOtp(otp: code, callback: callback)
    }

    func signInWithPhoneNumberRequestOtp(phoneNumber: String, callback: SignInWithPhoneNumberRequestOtpCallback) {
        payWingsOAuthClient.signInWithPhoneNumberRequestOtp(
            phoneNumber: phoneNumber,
            smsContentTemplate: nil,
            callback: callback
        )
    }

    func checkEmailVerified(callback: CheckEmailVerifiedCallback) {
        payWingsOAuthClient.checkEmailVerified(callback: callback)
    }
}
