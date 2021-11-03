import Foundation
import BigInt

protocol AcalaSpecificBonusServiceProtocol: CrowdloanBonusServiceProtocol {
    func applyOffchainBonusForTransfer(
        amount: BigUInt,
        email: String?,
        receiveEmails: Bool?,
        with closure: @escaping (Result<Void, Error>) -> Void
    )

    func applyOffchainBonusForContribution(
        amount: BigUInt,
        email: String?,
        receiveEmails: Bool?,
        with closure: @escaping (Result<Void, Error>) -> Void
    )
}

extension AcalaSpecificBonusServiceProtocol {
    func applyOffchainBonusForContribution(
        amount _: BigUInt,
        with _: @escaping (Result<Void, Error>) -> Void
    ) {}
}
