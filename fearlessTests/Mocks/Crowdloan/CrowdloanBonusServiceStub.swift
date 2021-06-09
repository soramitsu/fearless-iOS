import Foundation
@testable import fearless
import BigInt
import FearlessUtils

final class CrowdloanBonusServiceStub: CrowdloanBonusServiceProtocol {
    var termsURL: URL { URL(string: "https://google.com")! }

    var bonusRate: Decimal { 0.05 }

    private(set) var referralCode: String?

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        self.referralCode = referralCode

        closure(.success(()))
    }

    func applyOffchainBonusForContribution(
        amount: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        closure(.success(()))
    }

    func applyOnchainBonusForContribution(
        amount: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        return builder
    }
}
