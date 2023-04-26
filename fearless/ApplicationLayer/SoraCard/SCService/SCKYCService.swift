import Foundation
import PayWingsOAuthSDK
import UIKit

enum SCEndpoint: Endpoint {
    case getReferenceNumber
    case kycStatus
    case kycStatuses
    case kycAttemptCount
    case xOneStatus(paymentId: String)

    var path: String {
        switch self {
        case .getReferenceNumber:
            return "get-reference-number"
        case .kycStatus:
            return "kyc-last-status"
        case .kycStatuses:
            return "kyc-status"
        case .kycAttemptCount:
            return "kyc-attempt-count"
        case let .xOneStatus(paymentId):
            return "x1-payment-status/\(paymentId)"
        }
    }
}

final class SCKYCService {
    static let shared = SCKYCService(client: .shared)

    internal let client: SCAPIClient
    private let payWingsOAuthClient: PayWingsOAuthSDK.OAuthServiceProtocol
    private let eventCenter = EventCenter.shared
    private let tokenHolder = SCTokenHolder.shared

    init(client: SCAPIClient) {
        self.client = client

        let domain = SoraCardCIKeys.domain
        let apiKey = SoraCardCIKeys.apiKey
        PayWingsOAuthClient.initialize(environmentType: .TEST, apiKey: apiKey, domain: domain)

        payWingsOAuthClient = PayWingsOAuthClient.instance()!

        Task {
            await tokenHolder.loadToken()
            await kycStatuses()
        }
    }

    internal var userStatusYield: ((SCKYCUserStatus) -> Void)?

    lazy var userStatus: AsyncStream<SCKYCUserStatus> = {
        AsyncStream<SCKYCUserStatus> { [weak self] continuation in
            self?.userStatusYield = { status in
                continuation.yield(status)
            }
        }
    }()

    func refreshAccessTokenIfNeeded() async throws {
        let token = tokenHolder.token
        guard Date() >= Date(timeIntervalSince1970: TimeInterval(token.accessTokenExpirationTime)) else {
            return
        }

        return await withCheckedContinuation { continuation in

            self.payWingsOAuthClient.getNewAccessToken(refreshToken: token.refreshToken) { [weak self] result in
                if let data = result.accessTokenData {
                    let token = SCToken(
                        refreshToken: token.refreshToken,
                        accessToken: data.accessToken,
                        accessTokenExpirationTime: data.accessTokenExpirationTime
                    )
                    self?.tokenHolder.set(token: token)

                    Task {
                        continuation.resume()
                    }
                    return
                }

                if let errorData = result.errorData {
                    print("Error SCKYCService:\(errorData.error.rawValue) \(String(describing: errorData.errorMessage))")
                    continuation.resume()
                    return
                }
            }
        }
    }

    func sendNewVerificationEmail(callback: SendNewVerificationEmailCallback) {
        payWingsOAuthClient.sendNewVerificationEmail(callback: callback)
    }

    func getUserData(callback: GetUserDataCallback) {
        Task {
            guard !tokenHolder.token.isEmpty else {
                return
            }
            payWingsOAuthClient.getUserData(accessToken: tokenHolder.token.accessToken, callback: callback)
        }
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

    // https://api.coingecko.com/api/v3/simple/price?ids=sora&vs_currencies=eur
    func xorPriceInEuro() async -> Float? {
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=sora&vs_currencies=eur")!
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        let decoder = JSONDecoder()
        guard let fiatData = try? decoder.decode([String: [String: Float]].self, from: data) else { return nil }
        return fiatData["sora"]?["eur"] as? Float
    }
}
