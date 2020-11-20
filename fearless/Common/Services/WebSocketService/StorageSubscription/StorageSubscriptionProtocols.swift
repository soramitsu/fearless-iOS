import Foundation

protocol StorageChildSubscribing {
    var remoteStorageKey: Data { get }

    func processUpdate(_ data: Data?, blockHash: Data?)
}
