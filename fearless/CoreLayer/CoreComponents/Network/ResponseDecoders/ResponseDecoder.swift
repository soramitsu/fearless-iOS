import Foundation
import SSFUtils

protocol ResponseDecoder {
    func decode<T>(data: Data) throws -> T
}
