// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAccountManagment
@testable import SSFModels
@testable import SSFUtils
@testable import RobinHood

public class AccountManagebleMock: AccountManageble {
public init() {}

    //MARK: - getCurrentAccount

    public var getCurrentAccountCallsCount = 0
    public var getCurrentAccountCalled: Bool {
        return getCurrentAccountCallsCount > 0
    }
    public var getCurrentAccountReturnValue: MetaAccountModel?
    public var getCurrentAccountClosure: (() -> MetaAccountModel?)?

    public func getCurrentAccount() -> MetaAccountModel? {
        getCurrentAccountCallsCount += 1
        return getCurrentAccountClosure.map({ $0() }) ?? getCurrentAccountReturnValue
    }

    //MARK: - setCurrentAccount

    public var setCurrentAccountAccountCompletionClosureCallsCount = 0
    public var setCurrentAccountAccountCompletionClosureCalled: Bool {
        return setCurrentAccountAccountCompletionClosureCallsCount > 0
    }
    public var setCurrentAccountAccountCompletionClosureReceivedArguments: (account: MetaAccountModel, completionClosure: (Result<MetaAccountModel, Error>) -> Void)?
    public var setCurrentAccountAccountCompletionClosureReceivedInvocations: [(account: MetaAccountModel, completionClosure: (Result<MetaAccountModel, Error>) -> Void)] = []
    public var setCurrentAccountAccountCompletionClosureClosure: ((MetaAccountModel, @escaping (Result<MetaAccountModel, Error>) -> Void) -> Void)?

    public func setCurrentAccount(account: MetaAccountModel, completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void) {
        setCurrentAccountAccountCompletionClosureCallsCount += 1
        setCurrentAccountAccountCompletionClosureReceivedArguments = (account: account, completionClosure: completionClosure)
        setCurrentAccountAccountCompletionClosureReceivedInvocations.append((account: account, completionClosure: completionClosure))
        setCurrentAccountAccountCompletionClosureClosure?(account, completionClosure)
    }

    //MARK: - update

    public var updateVisibleForCompletionThrowableError: Error?
    public var updateVisibleForCompletionCallsCount = 0
    public var updateVisibleForCompletionCalled: Bool {
        return updateVisibleForCompletionCallsCount > 0
    }
    public var updateVisibleForCompletionReceivedArguments: (visible: Bool, chainAsset: ChainAsset, completion: () -> Void)?
    public var updateVisibleForCompletionReceivedInvocations: [(visible: Bool, chainAsset: ChainAsset, completion: () -> Void)] = []
    public var updateVisibleForCompletionClosure: ((Bool, ChainAsset, @escaping () -> Void) throws -> Void)?

    public func update(visible: Bool, for chainAsset: ChainAsset, completion: @escaping () -> Void) throws {
        if let error = updateVisibleForCompletionThrowableError {
            throw error
        }
        updateVisibleForCompletionCallsCount += 1
        updateVisibleForCompletionReceivedArguments = (visible: visible, chainAsset: chainAsset, completion: completion)
        updateVisibleForCompletionReceivedInvocations.append((visible: visible, chainAsset: chainAsset, completion: completion))
        try updateVisibleForCompletionClosure?(visible, chainAsset, completion)
    }

    //MARK: - logout

    public var logoutThrowableError: Error?
    public var logoutCallsCount = 0
    public var logoutCalled: Bool {
        return logoutCallsCount > 0
    }
    public var logoutClosure: (() throws -> Void)?

    public func logout() throws {
        if let error = logoutThrowableError {
            throw error
        }
        logoutCallsCount += 1
        try logoutClosure?()
    }

}
