import Foundation
import RobinHood
import SSFUtils
import BigInt

import IrohaCrypto

final class AstarBonusService {
    static let defaultReferralCode = "14Q22opa2mR3SsCZkHbDoSkN6iQpJPk6dDYwaQibufh41g3k"
    var bonusRate: Decimal { 0 }

    var termsURL: URL? {
        nil
    }

    private(set) var referralCode: String?

    let paraId: ParaId
    let operationManager: OperationManagerProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    init(paraId: ParaId, operationManager: OperationManagerProtocol, callFactory: SubstrateCallFactoryProtocol) {
        self.paraId = paraId
        self.operationManager = operationManager
        self.callFactory = callFactory
    }
}

extension AstarBonusService: CrowdloanBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        self.referralCode = referralCode
        closure(.success(()))
    }

    func applyOffchainBonusForContribution(
        amount _: BigUInt?,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        closure(.success(()))
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt?,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let addressFactory = SS58AddressFactory()

        guard let memo = referralCode, !memo.isEmpty,
              let memoData = try? addressFactory.accountId(from: memo)
        else {
            throw CrowdloanBonusServiceError.invalidReferral
        }

        let addMemo = callFactory.addMemo(to: paraId, memo: memoData)

        return try builder.adding(call: addMemo)
    }
}
