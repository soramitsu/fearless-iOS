// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFRuntimeCodingService
@testable import SSFUtils
@testable import RobinHood
@testable import SSFModels

public class RuntimeCodingServiceProtocolMock: RuntimeCodingServiceProtocol {
public init() {}
    public var snapshot: RuntimeSnapshot?

    //MARK: - fetchCoderFactoryOperation

    public var fetchCoderFactoryOperationCallsCount = 0
    public var fetchCoderFactoryOperationCalled: Bool {
        return fetchCoderFactoryOperationCallsCount > 0
    }
    public var fetchCoderFactoryOperationReturnValue: BaseOperation<RuntimeCoderFactoryProtocol>!
    public var fetchCoderFactoryOperationClosure: (() -> BaseOperation<RuntimeCoderFactoryProtocol>)?

    public func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        fetchCoderFactoryOperationCallsCount += 1
        return fetchCoderFactoryOperationClosure.map({ $0() }) ?? fetchCoderFactoryOperationReturnValue
    }

    //MARK: - fetchCoderFactory

    public var fetchCoderFactoryThrowableError: Error?
    public var fetchCoderFactoryCallsCount = 0
    public var fetchCoderFactoryCalled: Bool {
        return fetchCoderFactoryCallsCount > 0
    }
    public var fetchCoderFactoryReturnValue: RuntimeCoderFactoryProtocol!
    public var fetchCoderFactoryClosure: (() throws -> RuntimeCoderFactoryProtocol)?

    public func fetchCoderFactory() throws -> RuntimeCoderFactoryProtocol {
        if let error = fetchCoderFactoryThrowableError {
            throw error
        }
        fetchCoderFactoryCallsCount += 1
        return try fetchCoderFactoryClosure.map({ try $0() }) ?? fetchCoderFactoryReturnValue
    }

}
