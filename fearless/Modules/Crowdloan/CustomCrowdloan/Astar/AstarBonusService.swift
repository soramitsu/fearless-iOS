import Foundation
import RobinHood
import FearlessUtils
import BigInt
import CommonWallet

final class AstarBonusService {
    static let defaultReferralCode = "14Q22opa2mR3SsCZkHbDoSkN6iQpJPk6dDYwaQibufh41g3k"

    static let baseURL = URL(string: "https://salp-api.bifrost.finance")!

    var bonusRate: Decimal { 0 }

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
}

extension AstarBonusService: CrowdloanBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        self.referralCode = referralCode.data(using: .utf8)?.toHex(includePrefix: true)
        closure(.success(()))
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
