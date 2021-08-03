import Foundation
import BigInt
import FearlessUtils

protocol CrowdloanBonusServiceProtocol: AnyObject {
    var bonusRate: Decimal { get }
    var termsURL: URL { get }
    var referralCode: String? { get }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void)
    func applyOffchainBonusForContribution(
        amount: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    )

    func applyOnchainBonusForContribution(
        amount: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol
}
