import Foundation
import FearlessUtils
import BigInt

struct CrowdloanFunds: Codable, Equatable {
    let depositor: AccountId
    var verifier: MultiSigner?
    @StringCodable var deposit: BigUInt
    @StringCodable var raised: BigUInt
    @StringCodable var end: UInt32
    @StringCodable var cap: BigUInt
    let lastContribution: CrowdloanLastContribution
    @StringCodable var firstPeriod: UInt32
    @StringCodable var lastPeriod: UInt32
    @StringCodable var fundIndex: FundIndex
}
