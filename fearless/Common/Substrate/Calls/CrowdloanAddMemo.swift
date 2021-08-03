import Foundation
import FearlessUtils

struct CrowdloanAddMemo: Codable {
    @StringCodable var index: ParaId
    @BytesCodable var memo: Data
}
