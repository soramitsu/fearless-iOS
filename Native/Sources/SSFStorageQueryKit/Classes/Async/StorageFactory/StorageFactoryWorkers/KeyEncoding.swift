import Foundation

protocol StorageKeyEncoder {
    func performEncoding() throws -> [Data]
}
