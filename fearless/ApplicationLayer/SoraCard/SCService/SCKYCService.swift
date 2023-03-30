import Foundation
import PayWingsOAuthSDK

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
    let apiKey: String

    init(client: SCAPIClient) {
        self.client = client

        let domain = "soracard.com"
        let apiKey = SoraCardKeys.apiKey
        self.apiKey = apiKey

        PayWingsOAuthClient.initialize(environmentType: .TEST, apiKey: apiKey, domain: domain)

        payWingsOAuthClient = PayWingsOAuthClient.instance()!

        Task { await kycStatuses() }
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
        guard let token = await SCStorage.shared.token() else { return }
        guard Date() >= Date(timeIntervalSince1970: TimeInterval(token.accessTokenExpirationTime)) else {
            client.set(token: token)
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            self.payWingsOAuthClient.getNewAccessToken(refreshToken: token.refreshToken) { [weak self] result in
                if let data = result.accessTokenData {
                    let token = SCToken(
                        refreshToken: token.refreshToken,
                        accessToken: data.accessToken,
                        accessTokenExpirationTime: data.accessTokenExpirationTime
                    )
                    self?.client.set(token: token)

                    Task {
                        await SCStorage.shared.add(token: token)
                        continuation.resume()
                    }
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
            }
        }
    }

    func sendNewVerificationEmail(callback: SendNewVerificationEmailCallback) {
        payWingsOAuthClient.sendNewVerificationEmail(callback: callback)
    }

    func getUserData(callback: GetUserDataCallback) {
        Task {
            guard let token = await SCStorage.shared.token() else {
                return
            }
            payWingsOAuthClient.getUserData(accessToken: token.accessToken, callback: callback)
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
