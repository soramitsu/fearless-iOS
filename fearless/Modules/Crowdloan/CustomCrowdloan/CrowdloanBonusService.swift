import Foundation

protocol CrowdloanBonusServiceProtocol: AnyObject {
    var bonusRate: Decimal { get }
    var termsURL: URL { get }
    var referralCode: String? { get }

    func save(referrallCode: String, completion closure: (Result<Void, Error>) -> Void)
    func applyBonusForReward(_ reward: Decimal, with closure: (Result<Void, Error>) -> Void)
}
