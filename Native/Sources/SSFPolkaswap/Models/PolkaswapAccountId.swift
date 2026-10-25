import Foundation
import IrohaCrypto
import SSFUtils

struct PolkaswapAccountId: ScaleCodable {
    let value: Data

    init(scaleDecoder: ScaleDecoding) throws {
        value = try scaleDecoder.readAndConfirm(count: 32)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        scaleEncoder.appendRaw(data: value)
    }
}
