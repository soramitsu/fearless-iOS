import Foundation
import SSFUtils

extension ScaleEncodable {
    func scaleEncoded() throws -> Data {
        let scaleEncoder = ScaleEncoder()
        try encode(scaleEncoder: scaleEncoder)
        return scaleEncoder.encode()
    }
}
