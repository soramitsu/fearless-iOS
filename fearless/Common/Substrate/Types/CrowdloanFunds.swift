import Foundation
import FearlessUtils
import BigInt

struct CrowdloanFunds: Codable {
    let depositor: Data
    @NullCodable var verifier: MultiSigner?
    @StringCodable var deposit: BigUInt
    @StringCodable var raised: BigUInt
    @StringCodable var end: UInt32
    @StringCodable var cap: BigUInt
    let lastContribution: CrowdloanLastContribution
    @StringCodable var firstSlot: UInt32
    @StringCodable var lastSlot: UInt32
    @StringCodable var trieIndex: UInt32
}
