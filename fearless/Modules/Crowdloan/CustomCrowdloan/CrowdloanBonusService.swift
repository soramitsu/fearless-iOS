import Foundation

protocol CrowdloanBonusServiceProtocol: AnyObject {
    var bonusRate: Decimal { get }
    var termsURL: URL { get }
    var referralCode: String? { get }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void)
    func applyBonusForReward(_ reward: Decimal, with closure: @escaping (Result<Void, Error>) -> Void)
}
