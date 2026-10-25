// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAccountManagment
@testable import SSFModels
@testable import SSFUtils
@testable import RobinHood

public class AccountManagementWorkerProtocolMock: AccountManagementWorkerProtocol {
public init() {}

    //MARK: - save

    public var saveAccountCompletionCallsCount = 0
    public var saveAccountCompletionCalled: Bool {
        return saveAccountCompletionCallsCount > 0
    }
    public var saveAccountCompletionReceivedArguments: (account: ManagedMetaAccountModel, completion: () -> Void)?
    public var saveAccountCompletionReceivedInvocations: [(account: ManagedMetaAccountModel, completion: () -> Void)] = []
    public var saveAccountCompletionClosure: ((ManagedMetaAccountModel, @escaping () -> Void) -> Void)?

    public func save(account: ManagedMetaAccountModel, completion: @escaping () -> Void) {
        saveAccountCompletionCallsCount += 1
        saveAccountCompletionReceivedArguments = (account: account, completion: completion)
        saveAccountCompletionReceivedInvocations.append((account: account, completion: completion))
        saveAccountCompletionClosure?(account, completion)
    }

    //MARK: - fetchAll

    public var fetchAllThrowableError: Error?
    public var fetchAllCallsCount = 0
    public var fetchAllCalled: Bool {
        return fetchAllCallsCount > 0
    }
    public var fetchAllReturnValue: [MetaAccountModel]!
    public var fetchAllClosure: (() throws -> [MetaAccountModel])?

    public func fetchAll() throws -> [MetaAccountModel] {
        if let error = fetchAllThrowableError {
            throw error
        }
        fetchAllCallsCount += 1
        return try fetchAllClosure.map({ try $0() }) ?? fetchAllReturnValue
    }

    //MARK: - deleteAll

    public var deleteAllCompletionCallsCount = 0
    public var deleteAllCompletionCalled: Bool {
        return deleteAllCompletionCallsCount > 0
    }
    public var deleteAllCompletionReceivedCompletion: (() -> Void)?
    public var deleteAllCompletionReceivedInvocations: [(() -> Void)] = []
    public var deleteAllCompletionClosure: ((@escaping () -> Void) -> Void)?

    public func deleteAll(completion: @escaping () -> Void) {
        deleteAllCompletionCallsCount += 1
        deleteAllCompletionReceivedCompletion = completion
        deleteAllCompletionReceivedInvocations.append(completion)
        deleteAllCompletionClosure?(completion)
    }

}
