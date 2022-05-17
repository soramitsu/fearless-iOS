import Foundation
import RobinHood

protocol AnyProviderAutoCleaning {
    func clear<T>(singleValueProvider: inout AnySingleValueProvider<T>?)
    func clear<T>(dataProvider: inout AnyDataProvider<T>?)
    func clear<T>(streamableProvider: inout StreamableProvider<T>?)
}

extension AnyProviderAutoCleaning where Self: AnyObject {
    func clear<T>(singleValueProvider: inout AnySingleValueProvider<T>?) {
        singleValueProvider?.removeObserver(self)
        singleValueProvider = nil
    }

    func clear<T>(dataProvider: inout AnyDataProvider<T>?) {
        dataProvider?.removeObserver(self)
        dataProvider = nil
    }

    func clear<T>(streamableProvider: inout StreamableProvider<T>?) {
        streamableProvider?.removeObserver(self)
        streamableProvider = nil
    }
}
