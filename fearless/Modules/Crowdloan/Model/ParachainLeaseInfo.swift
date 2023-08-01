import Foundation
import BigInt

struct ParachainLeaseInfo {
    let paraId: ParaId
    let fundAccountId: AccountId
    let leasedAmount: BigUInt?
}

typealias ParachainLeaseInfoList = [ParachainLeaseInfo]
typealias ParachainLeaseInfoDict = [ParaId: ParachainLeaseInfo]

extension ParachainLeaseInfoList {
    func toMap() -> ParachainLeaseInfoDict {
        reduce(into: ParachainLeaseInfoDict()) { dict, info in
            dict[info.paraId] = info
        }
    }
}
