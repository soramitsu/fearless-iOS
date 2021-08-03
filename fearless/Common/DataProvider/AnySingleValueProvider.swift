import Foundation
import RobinHood

public class AnySingleValueProvider<T>: SingleValueProviderProtocol {
    public typealias Model = T

    private let fetchClosure: (((Result<T?, Error>?) -> Void)?) -> CompoundOperationWrapper<T?>

    private let addObserverClosure: (
        AnyObject,
        DispatchQueue?,
        @escaping ([DataProviderChange<T>]) -> Void,
        @escaping (Error) -> Void,
        DataProviderObserverOptions
    ) -> Void

    private let removeObserverClosure: (AnyObject) -> Void

    private let refreshClosure: () -> Void

    public private(set) var executionQueue: OperationQueue

    public init<U: SingleValueProviderProtocol>(_ dataProvider: U) where U.Model == Model {
        fetchClosure = dataProvider.fetch(with:)
        addObserverClosure = dataProvider.addObserver
        removeObserverClosure = dataProvider.removeObserver
        refreshClosure = dataProvider.refresh
        executionQueue = dataProvider.executionQueue
    }

    public func fetch(with completionBlock: ((Result<T?, Error>?) -> Void)?) -> CompoundOperationWrapper<T?> {
        fetchClosure(completionBlock)
    }

    public func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options: DataProviderObserverOptions
    ) {
        addObserverClosure(observer, queue, updateBlock, failureBlock, options)
    }

    public func removeObserver(_ observer: AnyObject) {
        removeObserverClosure(observer)
    }

    public func refresh() {
        refreshClosure()
    }
}
