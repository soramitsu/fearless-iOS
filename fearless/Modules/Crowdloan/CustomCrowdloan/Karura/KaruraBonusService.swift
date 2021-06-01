import Foundation
import RobinHood
import BigInt
import IrohaCrypto

enum KaruraBonusServiceError: Error, ErrorContentConvertible {
    case invalidReferral
    case internalError
    case veficationFailed

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
        case .veficationFailed:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: "Signature verification failed."
            )
        }
    }
}

final class KaruraBonusService {
    static let defaultReferralCode = "0x9642d0db9f3b301b44df74b63b0b930011e3f52154c5ca24b4dc67b3c7322f15"

    #if F_RELEASE
        static let baseURL = URL(string: "https://api.aca-staging.network")!
    #else
        static let baseURL = URL(string: "https://crowdloan-api.laminar.codes")!
    #endif

    static let apiReferral = "/referral"
    static let apiStatement = "/statement"
    static let apiVerify = "/verify"

    var bonusRate: Decimal { 0.05 }
    var termsURL: URL { URL(string: "https://acala.network/karura/terms")! }
    private(set) var referralCode: String?

    let signingWrapper: SigningWrapperProtocol
    let address: AccountAddress
    let chain: Chain
    let operationManager: OperationManagerProtocol

    init(
        address: AccountAddress,
        chain: Chain,
        signingWrapper: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.address = address
        self.chain = chain
        self.signingWrapper = signingWrapper
        self.operationManager = operationManager
    }

    func createStatementFetchOperation() -> BaseOperation<String> {
        let url = Self.baseURL.appendingPathComponent(Self.apiStatement)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            let resultData = try JSONDecoder().decode(
                KaruraStatementData.self,
                from: data
            )

            return resultData.statement
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createVerifyOperation(
        dependingOn infoOperation: BaseOperation<KaruraVerifyInfo>
    ) -> BaseOperation<Void> {
        let url = Self.baseURL
            .appendingPathComponent(Self.apiVerify)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            let info = try infoOperation.extractNoCancellableResultData()
            request.httpBody = try JSONEncoder().encode(info)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> { data in
            let resultData = try JSONDecoder().decode(
                KaruraResultData.self,
                from: data
            )

            guard resultData.result else {
                throw KaruraBonusServiceError.veficationFailed
            }
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}

extension KaruraBonusService: CrowdloanBonusServiceProtocol {
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
                KaruraResultData.self,
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

    func applyBonusForContribution(amount: BigUInt, with closure: @escaping (Result<Void, Error>) -> Void) {
        guard let referralCode = referralCode else {
            DispatchQueue.main.async {
                closure(.failure(KaruraBonusServiceError.veficationFailed))
            }

            return
        }

        let statementOperation = createStatementFetchOperation()

        let infoOperation = ClosureOperation<KaruraVerifyInfo> {
            guard
                let statement = try statementOperation.extractNoCancellableResultData().data(using: .utf8) else {
                throw KaruraBonusServiceError.veficationFailed
            }

            let signedData = try self.signingWrapper.sign(statement)

            let addressFactory = SS58AddressFactory()
            let accountId = try addressFactory.accountId(from: self.address)
            let addressType = self.chain == .rococo ? SNAddressType.genericSubstrate : self.chain.addressType
            let finalAddress = try addressFactory.addressFromAccountId(data: accountId, type: addressType)

            return KaruraVerifyInfo(
                address: finalAddress,
                amount: String(amount),
                signature: signedData.rawData().toHex(includePrefix: true),
                referral: referralCode
            )
        }

        infoOperation.addDependency(statementOperation)

        let verifyOperation = createVerifyOperation(dependingOn: infoOperation)
        verifyOperation.addDependency(infoOperation)

        verifyOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try verifyOperation.extractNoCancellableResultData()
                    closure(.success(()))
                } catch {
                    closure(.failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [statementOperation, infoOperation, verifyOperation], in: .transient)
    }
}
