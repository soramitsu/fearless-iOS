import Foundation
import SSFUtils

struct CrowdloanAddMemo: Codable {
    @StringCodable var index: ParaId
    @BytesCodable var memo: Data
}
