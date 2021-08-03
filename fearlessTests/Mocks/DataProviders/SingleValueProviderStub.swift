import Foundation
import RobinHood
@testable import fearless

final class SingleValueProviderStub<T>: SingleValueProviderProtocol {
    typealias Model = T

    let item: T?

    let executionQueue: OperationQueue = OperationQueue()

    init(item: T?) {
        self.item = item
    }

    func fetch(with completionBlock: ((Result<Model?, Error>?) -> Void)?) -> CompoundOperationWrapper<Model?> {
        CompoundOperationWrapper.createWithResult(item)
    }

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions) {
        let changes: [DataProviderChange<T>]

        if let item = item {
            changes = [DataProviderChange.insert(newItem: item)]
        } else {
            changes = []
        }

        dispatchInQueueWhenPossible(queue) {
            updateBlock(changes)
        }
    }

    func removeObserver(_ observer: AnyObject) {}

    func refresh() {}
}
