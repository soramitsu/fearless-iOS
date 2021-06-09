import Foundation
import BigInt
import FearlessUtils

protocol CrowdloanBonusServiceProtocol: AnyObject {
    var bonusRate: Decimal { get }
    var termsURL: URL { get }
    var referralCode: String? { get }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void)
    func applyBonusForContribution(amount: BigUInt, with closure: @escaping (Result<Void, Error>) -> Void)
    func applyOnChain(for builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol
}
