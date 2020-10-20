import Foundation

protocol StorageChildSubscribing {
    var storageKey: Data { get }

    func processUpdate(_ data: Data?, blockHash: Data?)
}
