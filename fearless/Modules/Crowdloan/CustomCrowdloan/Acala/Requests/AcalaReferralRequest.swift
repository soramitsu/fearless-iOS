import Foundation

struct AcalaReferralRequest: HTTPRequestConfig {
    let referralCode: String

    var headers: [String: String]? {
        nil
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        nil
    }

    var path: String {
        "/referral".appending("/\(referralCode)")
    }

    var httpMethod: String {
        HTTPRequestMethod.get.rawValue
    }
}
