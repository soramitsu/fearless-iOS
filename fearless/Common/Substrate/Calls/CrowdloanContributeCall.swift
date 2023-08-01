import Foundation
import SSFUtils
import BigInt

struct CrowdloanContributeCall: Codable {
    @StringCodable var index: ParaId
    @StringCodable var value: BigUInt
    @NullCodable var signature: MultiSignature?
}
