import Foundation
import FearlessUtils

protocol ResponseDecoder {
    func decode<T>(data: Data) throws -> T
}
