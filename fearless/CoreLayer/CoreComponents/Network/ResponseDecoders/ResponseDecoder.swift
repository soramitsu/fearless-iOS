import Foundation

protocol ResponseDecoder {
    func decode<T>(data: Data) throws -> T
}
