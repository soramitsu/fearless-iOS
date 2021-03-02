import Foundation
import RobinHood
@testable import fearless

final class DataProviderStub<T: Identifiable>: DataProviderProtocol {
    typealias Model = T

    let models: [T]

    let executionQueue: OperationQueue = OperationQueue()

    init(models: [T]) {
        self.models = models
    }

    func fetch(by modelId: String,
               completionBlock: ((Result<Model?, Error>?) -> Void)?) -> CompoundOperationWrapper<Model?> {
        let model = models.first(where: { $0.identifier == modelId })
        return CompoundOperationWrapper.createWithResult(model)
    }

    func fetch(page index: UInt,
               completionBlock: ((Result<[Model], Error>?) -> Void)?) -> CompoundOperationWrapper<[Model]> {
        CompoundOperationWrapper.createWithResult(models)
    }

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions) {
        let changes = models.map { DataProviderChange.insert(newItem: $0) }
        dispatchInQueueWhenPossible(queue) {
            updateBlock(changes)
        }
    }

    func removeObserver(_ observer: AnyObject) {}

    func refresh() {}
}
