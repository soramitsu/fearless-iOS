import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class BifrostBonusService {
    static let defaultReferralCode = "FRLS69"

    static let baseURL = URL(string: "https://salp-api.bifrost.finance")!

    var bonusRate: Decimal { 0.05 }

    var termsURL: URL {
        URL(string: "https://docs.google.com/document/d/1PDpgHnIcAmaa7dEFusmLYgjlvAbk2VKtMd755bdEsf4/edit?usp=sharing")!
    }

    private(set) var referralCode: String?

    let paraId: ParaId
    let operationManager: OperationManagerProtocol

    init(paraId: ParaId, operationManager: OperationManagerProtocol) {
        self.paraId = paraId
        self.operationManager = operationManager
    }

    func createVerifyOperation(
        for code: String
    ) -> BaseOperation<String> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: Self.baseURL)

            let params = "{getAccountByInvitationCode(code: \"\(code)\"){account}}"
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            let resultData = try JSONDecoder().decode(JSON.self, from: data)

            guard let account = resultData.data?.getAccountByInvitationCode?.account?.stringValue else {
                throw CrowdloanBonusServiceError.internalError
            }

            return account
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}

extension BifrostBonusService: CrowdloanBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        let verifyOperation = createVerifyOperation(for: referralCode)

        verifyOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let account = try verifyOperation.extractNoCancellableResultData()

                    if !account.isEmpty {
                        self?.referralCode = referralCode
                        closure(.success(()))
                    } else {
                        closure(.failure(CrowdloanBonusServiceError.invalidReferral))
                    }

                } catch {
                    closure(.failure(CrowdloanBonusServiceError.internalError))
                }
            }
        }

        operationManager.enqueue(operations: [verifyOperation], in: .transient)
    }

    func applyOffchainBonusForContribution(
        amount _: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        closure(.success(()))
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard let memo = referralCode?.data(using: .utf8), memo.count <= 32 else {
            throw CrowdloanBonusServiceError.invalidReferral
        }

        let addMemo = SubstrateCallFactory().addMemo(to: paraId, memo: memo)

        return try builder.adding(call: addMemo)
    }
}
