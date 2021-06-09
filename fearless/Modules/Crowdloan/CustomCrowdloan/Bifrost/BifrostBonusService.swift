import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class BifrostBonusService {
    static let defaultReferralCode = "FRLS69"

    var bonusRate: Decimal { 0.05 }

    var termsURL: URL {
        URL(string: "https://docs.google.com/document/d/1PDpgHnIcAmaa7dEFusmLYgjlvAbk2VKtMd755bdEsf4/edit?usp=sharing")!
    }

    private(set) var referralCode: String?

    let paraId: ParaId

    init(paraId: ParaId) {
        self.paraId = paraId
    }
}

extension BifrostBonusService: CrowdloanBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        guard let codeData = referralCode.data(using: .utf8), codeData.count <= 32 else {
            closure(.failure(CrowdloanBonusServiceError.invalidReferral))
            return
        }

        self.referralCode = referralCode
        closure(.success(()))
    }

    func applyBonusForContribution(amount _: BigUInt, with closure: @escaping (Result<Void, Error>) -> Void) {
        closure(.success(()))
    }

    func applyOnChain(for builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol {
        guard let memo = referralCode?.data(using: .utf8) else {
            return builder
        }

        let addMemo = SubstrateCallFactory().addMemo(to: paraId, memo: memo)

        return try builder.adding(call: addMemo)
    }
}
