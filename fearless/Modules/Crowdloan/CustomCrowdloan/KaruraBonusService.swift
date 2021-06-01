import Foundation

final class KaruraBonusService: CrowdloanBonusServiceProtocol {
    var bonusRate: Decimal { 0.05 }
    private(set) var referralCode: String?

    func save(referrallCode _: String, completion _: (Result<Void, Error>) -> Void) {}

    func applyBonusForReward(_: Decimal, with _: (Result<Void, Error>) -> Void) {}
}
