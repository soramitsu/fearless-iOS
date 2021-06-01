import Foundation

final class KaruraBonusService: CrowdloanBonusServiceProtocol {
    static let defaultReferralCode = "0x9642d0db9f3b301b44df74b63b0b930011e3f52154c5ca24b4dc67b3c7322f15"

    var bonusRate: Decimal { 0.05 }
    var termsURL: URL { URL(string: "https://acala.network/karura/terms")! }
    private(set) var referralCode: String?

    func save(referrallCode _: String, completion _: (Result<Void, Error>) -> Void) {}

    func applyBonusForReward(_: Decimal, with _: (Result<Void, Error>) -> Void) {}
}
