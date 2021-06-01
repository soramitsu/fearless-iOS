import Foundation
import RobinHood

enum KaruraBonusServiceError: Error, ErrorContentConvertible {
    case invalidReferral
    case internalError

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .invalidReferral:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.crowdloanReferralCodeInvalid(preferredLanguages: locale?.rLanguages)
            )
        case .internalError:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.crowdloanReferralCodeInternal(preferredLanguages: locale?.rLanguages)
            )
        }
    }
}

final class KaruraBonusService: CrowdloanBonusServiceProtocol {
    static let defaultReferralCode = "0x9642d0db9f3b301b44df74b63b0b930011e3f52154c5ca24b4dc67b3c7322f15"

    #if F_RELEASE
        static let baseURL = URL(string: "https://api.aca-staging.network")!
    #else
        static let baseURL = URL(string: "https://crowdloan-api.laminar.codes")!
    #endif

    static let apiReferral = "/referral"
    static let apiApply = "/verify"

    var bonusRate: Decimal { 0.05 }
    var termsURL: URL { URL(string: "https://acala.network/karura/terms")! }
    private(set) var referralCode: String?

    let operationManager: OperationManagerProtocol

    init(operationManager: OperationManagerProtocol) {
        self.operationManager = operationManager
    }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        let url = Self.baseURL
            .appendingPathComponent(Self.apiReferral)
            .appendingPathComponent(referralCode)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(
                KaruraReferralData.self,
                from: data
            )

            return resultData.result
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operation.extractNoCancellableResultData()

                    if result {
                        self?.referralCode = referralCode
                        closure(.success(()))
                    } else {
                        closure(.failure(KaruraBonusServiceError.invalidReferral))
                    }

                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .invalidParameters {
                        closure(.failure(KaruraBonusServiceError.invalidReferral))
                    } else {
                        closure(.failure(KaruraBonusServiceError.internalError))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func applyBonusForReward(_: Decimal, with _: @escaping (Result<Void, Error>) -> Void) {}
}
