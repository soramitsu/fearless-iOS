import Foundation
@testable import fearless
import BigInt

final class CrowdloanBonusServiceStub: CrowdloanBonusServiceProtocol {
    var termsURL: URL { URL(string: "https://google.com")! }

    var bonusRate: Decimal { 0.05 }

    private(set) var referralCode: String?

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        self.referralCode = referralCode

        closure(.success(()))
    }

    func applyBonusForContribution(amount: BigUInt, with closure: @escaping (Result<Void, Error>) -> Void) {
        closure(.success(()))
    }
}
