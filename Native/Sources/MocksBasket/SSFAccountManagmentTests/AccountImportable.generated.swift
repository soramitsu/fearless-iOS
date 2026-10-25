// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAccountManagment
@testable import SSFModels
@testable import SSFUtils
@testable import RobinHood

public class AccountImportableMock: AccountImportable {
public init() {}

    //MARK: - importMetaAccount

    public var importMetaAccountRequestThrowableError: Error?
    public var importMetaAccountRequestCallsCount = 0
    public var importMetaAccountRequestCalled: Bool {
        return importMetaAccountRequestCallsCount > 0
    }
    public var importMetaAccountRequestReceivedRequest: MetaAccountImportRequest?
    public var importMetaAccountRequestReceivedInvocations: [MetaAccountImportRequest] = []
    public var importMetaAccountRequestReturnValue: MetaAccountModel!
    public var importMetaAccountRequestClosure: ((MetaAccountImportRequest) throws -> MetaAccountModel)?

    public func importMetaAccount(request: MetaAccountImportRequest) throws -> MetaAccountModel {
        if let error = importMetaAccountRequestThrowableError {
            throw error
        }
        importMetaAccountRequestCallsCount += 1
        importMetaAccountRequestReceivedRequest = request
        importMetaAccountRequestReceivedInvocations.append(request)
        return try importMetaAccountRequestClosure.map({ try $0(request) }) ?? importMetaAccountRequestReturnValue
    }

}
